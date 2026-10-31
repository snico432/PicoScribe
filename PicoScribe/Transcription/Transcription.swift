/*
See LICENSE.txt for licensing information.

Abstract:
Live speech-to-text via SpeechAnalyzer.
*/

import Foundation
import Speech
import SwiftUI

@Observable
final class SpokenWordTranscriber {
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), Error>?

    var analyzerFormat: AVAudioFormat?
    var converter = BufferConverter()
    var downloadProgress: Progress?

    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""

    /// Called whenever a finalized chunk of transcript text is available.
    var onFinalText: ((String) -> Void)?

    private var reservedLocale: Locale?
    private var didReserveLocale = false

    func setUpTranscriber() async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            throw TranscriptionError.localeNotSupported
        }

        try await reserveLocaleIfNeeded(locale)

        transcriber = SpeechTranscriber(locale: locale,
                                        transcriptionOptions: [],
                                        reportingOptions: [.volatileResults],
                                        attributeOptions: [])

        guard let transcriber else {
            throw TranscriptionError.failedToSetupRecognitionStream
        }

        do {
            try await ensureModel(transcriber: transcriber, locale: locale)
        } catch let error as TranscriptionError {
            print(error)
            await releaseReservedLocaleIfNeeded()
            return
        }

        analyzer = SpeechAnalyzer(modules: [transcriber])

        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        guard let inputSequence else { return }

        recognizerTask = Task {
            do {
                for try await case let result in transcriber.results {
                    let text = result.text
                    if result.isFinal {
                        finalizedTranscript += text
                        volatileTranscript = ""
                        onFinalText?(String(text.characters))
                    } else {
                        volatileTranscript = text
                        volatileTranscript.foregroundColor = .purple.opacity(0.4)
                    }
                }
            } catch {
                print("speech recognition failed")
            }
        }

        try await analyzer?.start(inputSequence: inputSequence)
    }

    func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw TranscriptionError.invalidAudioDataType
        }

        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)
        
        inputBuilder.yield(input)
    }

    func finishTranscribing() async throws {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil
        await releaseReservedLocaleIfNeeded()
    }

    func resetTranscript() {
        finalizedTranscript = AttributedString("")
        volatileTranscript = AttributedString("")
    }
}

extension SpokenWordTranscriber {
    func reserveLocaleIfNeeded(_ locale: Locale) async throws {
        let reserved = await AssetInventory.reservedLocales
        let localeIdentifier = locale.identifier(.bcp47)

        if reserved.map({ $0.identifier(.bcp47) }).contains(localeIdentifier) {
            reservedLocale = locale
            return
        }

        if reserved.count >= AssetInventory.maximumReservedLocales,
           let oldest = reserved.last {
            await AssetInventory.release(reservedLocale: oldest)
        }

        didReserveLocale = try await AssetInventory.reserve(locale: locale)
        if didReserveLocale {
            reservedLocale = locale
        }
    }

    func releaseReservedLocaleIfNeeded() async {
        guard didReserveLocale, let locale = reservedLocale else { return }
        await AssetInventory.release(reservedLocale: locale)
        reservedLocale = nil
        didReserveLocale = false
    }

    func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw TranscriptionError.localeNotSupported
        }

        if await installed(locale: locale) {
            return
        } else {
            try await downloadIfNeeded(for: transcriber)
        }
    }

    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            self.downloadProgress = downloader.progress
            try await downloader.downloadAndInstall()
        }
    }

    func releaseLocales() async {
        let reserved = await AssetInventory.reservedLocales
        for locale in reserved {
            await AssetInventory.release(reservedLocale: locale)
        }
    }
}
