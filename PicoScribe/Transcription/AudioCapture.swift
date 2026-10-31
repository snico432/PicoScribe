/*
See LICENSE.txt for licensing information.

Abstract:
Microphone capture for live transcription.
*/

import Foundation
import AVFoundation

class AudioCapture {
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private let audioEngine: AVAudioEngine
    private let transcriber: SpokenWordTranscriber

    init(transcriber: SpokenWordTranscriber) {
        audioEngine = AVAudioEngine()
        self.transcriber = transcriber
    }

    func start() async throws {
        guard await isAuthorized() else {
            print("user denied mic permission")
            return
        }
#if os(iOS)
        try setUpAudioSession()
#endif
        try await transcriber.setUpTranscriber()

        for await input in try await audioStream() {
            try await self.transcriber.streamAudioToTranscriber(input)
        }
    }

    func stop() async throws {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try await transcriber.finishTranscribing()
    }

#if os(iOS)
    private func setUpAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
#endif

    private func audioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0,
                             bufferSize: 4096,
                             format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.outputContinuation?.yield(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
            outputContinuation = continuation
        }
    }

    private func isAuthorized() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
}
