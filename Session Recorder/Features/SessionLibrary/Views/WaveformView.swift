import SwiftUI

/// Whole-session waveform (RF-2): bars mirrored around the center, drawn for the full duration so a
/// partial waveform fills left to right. Playback position, seeking and trim handles are added later.
struct WaveformView: View {
    let waveform: WaveformData?
    /// Session duration (the waveform may still be shorter while it is computed).
    let duration: TimeInterval
    var isLoading = false

    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            guard let waveform, duration > 0 else { return }
            let barCount = max(Int(size.width / (barWidth + barSpacing)), 1)
            let bars = SessionLibraryLogic.waveformBars(waveform, visible: 0...duration, barCount: barCount)
            let loadedBars = Int((min(waveform.duration / duration, 1) * Double(barCount)).rounded(.down))
            let midY = size.height / 2
            for (index, value) in bars.prefix(loadedBars).enumerated() {
                // Linear peak scale (like most audio editors), so loud and quiet parts differ clearly.
                let height = max(CGFloat(value) * size.height, 1)
                let x = CGFloat(index) * (barWidth + barSpacing)
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.accentColor))
            }
        }
        .overlay {
            if waveform == nil && isLoading {
                ProgressView()
            }
        }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityValue(isLoading ? "Loading" : "\(SessionLibraryLogic.formatPlaybackTime(duration)) long")
    }
}

#Preview("Waveform") {
    let peaks = (0..<600).map { index in Float(abs(sin(Double(index) / 25))) * 0.8 }
    VStack(spacing: 16) {
        WaveformView(waveform: WaveformData(peaksPerSecond: 10, peaks: peaks), duration: 60)
        WaveformView(waveform: WaveformData(peaksPerSecond: 10, peaks: Array(peaks.prefix(250))), duration: 60, isLoading: true)
        WaveformView(waveform: nil, duration: 60, isLoading: true)
    }
    .frame(height: 360)
    .padding()
}
