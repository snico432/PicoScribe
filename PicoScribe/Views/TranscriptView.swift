/*
See LICENSE.txt for licensing information.

Abstract:
Live transcription UI with BLE output to the Pico 2 W.
*/

import SwiftUI
import Speech

struct TranscriptionView: View {
    @State private var isTranscribing = false
    @State private var transcriber: SpokenWordTranscriber
    @State private var audioCapture: AudioCapture
    @State private var bleManager = BLEManager()
    @State private var showDevicePicker = false
    @State private var downloadProgress = 0.0

    init() {
        let transcriber = SpokenWordTranscriber()
        _transcriber = State(wrappedValue: transcriber)
        _audioCapture = State(wrappedValue: AudioCapture(transcriber: transcriber))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(transcriber.finalizedTranscript + transcriber.volatileTranscript)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                if case .failed(let message) = bleManager.connectionState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                transcribeButton
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("PicoScribe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    bleActionButton

                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(bleStatusColor)
                }
                .padding(.trailing, 4)
            }
        }
        .task(id: transcriber.downloadProgress) {
            guard let progress = transcriber.downloadProgress else {
                downloadProgress = 0
                return
            }
            while !progress.isFinished && !Task.isCancelled {
                downloadProgress = progress.fractionCompleted * 100
                try? await Task.sleep(for: .milliseconds(100))
            }
            downloadProgress = progress.isFinished ? 100 : 0
        }
        .sheet(isPresented: $showDevicePicker) {
            devicePickerSheet
        }
        .sheet(isPresented: isDownloadingModel) {
            modelDownloadSheet
        }
        .onChange(of: isTranscribing) { _, newValue in
            if newValue {
                transcriber.resetTranscript()
                transcriber.onFinalText = { text in
                    bleManager.sendText(text)
                }
                Task {
                    do {
                        try await audioCapture.start()
                    } catch {
                        print("could not start transcription: \(error)")
                        isTranscribing = false
                    }
                }
            } else {
                transcriber.onFinalText = nil
                Task {
                    try await audioCapture.stop()
                }
            }
        }
    }

    @ViewBuilder
    private var modelDownloadSheet: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Downloading Speech Model")
                .font(.title2)

            Text("The on-device speech model for your language is being downloaded. This only needs to happen once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ProgressView(value: downloadProgress, total: 100)
                .progressViewStyle(.linear)

            Text("\(Int(downloadProgress))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private var isDownloadingModel: Binding<Bool> {
        Binding(
            get: {
                guard let progress = transcriber.downloadProgress else { return false }
                return !progress.isFinished
            },
            set: { _ in }
        )
    }

    @ViewBuilder
    private var transcribeButton: some View {
        Button {
            handleTranscribeButtonTap()
        } label: {
            Image(systemName: isTranscribing ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red)
        }
        .accessibilityLabel(isTranscribing ? "Stop" : "Transcribe")
    }

    @ViewBuilder
    private var bleActionButton: some View {
        if bleManager.connectionState == .connected {
            Button {
                bleManager.disconnect()
            } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .accessibilityLabel("Disconnect Pico")
        } else if bleManager.connectionState == .scanning {
            Button {
                bleManager.stopScanning()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Cancel")
        } else if bleManager.connectionState == .connecting {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                bleManager.startScanning()
                showDevicePicker = true
            } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .accessibilityLabel("Connect Pico")
        }
    }

    @ViewBuilder
    private var devicePickerSheet: some View {
        NavigationStack {
            List {
                Section("Devices") {
                    if bleManager.discoveredDevices.isEmpty && bleManager.connectionState == .scanning {
                        ContentUnavailableView("Scanning…",
                                               systemImage: "antenna.radiowaves.left.and.right",
                                               description: Text("Make sure your Pico 2 W is advertising."))
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                            Button {
                                bleManager.connect(to: device)
                                showDevicePicker = false
                            } label: {
                                HStack {
                                    Text(device.name ?? "Unknown")
                                    Spacer()
                                    if bleManager.connectionState == .connecting {
                                        ProgressView()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pico Devices")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        bleManager.stopScanning()
                        showDevicePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var bleStatusColor: Color {
        switch bleManager.connectionState {
        case .connected: .green
        case .scanning, .connecting: .yellow
        case .disconnected: .gray
        case .failed: .red
        }
    }

    private func handleTranscribeButtonTap() {
        isTranscribing.toggle()
    }
}
