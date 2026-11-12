import SwiftUI

extension EnvironmentValues {
    /// Set by ContentView; nil in contexts without recording (e.g., source sheet previews).
    @Entry var recordingViewModel: RecordingViewModel? = nil
}

/// Quality section of the source sheet: sample rate and bit depth for the selected device (RF-1).
struct RecordingQualitySection: View {
    @Environment(\.recordingViewModel) private var recordingViewModel

    var body: some View {
        if let recordingViewModel {
            QualityPickers(viewModel: recordingViewModel)
        }
    }
}

private struct QualityPickers: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        if let quality = viewModel.quality, !viewModel.offeredQualities.isEmpty {
            Section {
                Picker("Sample rate", selection: sampleRateBinding(current: quality)) {
                    ForEach(offeredSampleRates, id: \.self) { rate in
                        Text(RecordingQuality.formatSampleRate(rate)).tag(rate)
                    }
                }
                Picker("Bit depth", selection: bitDepthBinding(current: quality)) {
                    ForEach(RecordingLogic.allowedBitDepths, id: \.self) { bitDepth in
                        Text("\(bitDepth)-bit").tag(bitDepth)
                    }
                }
            } header: {
                Text("Quality")
            } footer: {
                Text(footerText(for: quality))
            }
        }
    }

    private var offeredSampleRates: [Double] {
        Array(Set(viewModel.offeredQualities.map(\.sampleRate))).sorted()
    }

    private func sampleRateBinding(current: RecordingQuality) -> Binding<Double> {
        Binding(
            get: { current.sampleRate },
            set: { viewModel.selectQuality(RecordingQuality(sampleRate: $0, bitDepth: current.bitDepth)) }
        )
    }

    private func bitDepthBinding(current: RecordingQuality) -> Binding<Int> {
        Binding(
            get: { current.bitDepth },
            set: { viewModel.selectQuality(RecordingQuality(sampleRate: current.sampleRate, bitDepth: $0)) }
        )
    }

    /// Storage per hour for the current channels, e.g. `About 1 GB per hour (stereo).`
    private func footerText(for quality: RecordingQuality) -> String {
        let channelCount = max(viewModel.meteredChannelCount, 1)
        let bytesPerHour = RecordingLogic.bytesPerSecond(quality: quality, channelCount: channelCount) * 3600
        let mode = channelCount == 2 ? "stereo" : "mono"
        return "About \(RecordingLogic.formatFileSize(Int64(bytesPerHour))) per hour (\(mode)). Saved for this device."
    }
}
