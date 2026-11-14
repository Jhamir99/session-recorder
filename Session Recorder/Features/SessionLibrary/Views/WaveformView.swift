import SwiftUI

/// Whole-session waveform (RF-2): bars mirrored around the center, drawn for the full duration so a
/// partial waveform fills left to right. With `progress`, shows the playhead; with `onSeek`, tapping or
/// dragging moves it. Trim handles are added later.
struct WaveformView: View {
    let waveform: WaveformData?
    /// Session duration (the waveform may still be shorter while it is computed).
    let duration: TimeInterval
    var isLoading = false
    var progress: PlaybackProgress?
    var onSeek: ((TimeInterval) -> Void)?
    /// Trim mode (RF-5): handles at the range edges; outside the range is dimmed.
    var trimRange: TrimRange?
    var onTrimStart: ((TimeInterval) -> Void)?
    var onTrimEnd: ((TimeInterval) -> Void)?

    @State private var width: CGFloat = 0

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
        .overlay {
            if let progress {
                Playhead(progress: progress, duration: duration)
            }
        }
        .overlay {
            if let trimRange {
                TrimOverlay(
                    range: trimRange,
                    duration: duration,
                    onStart: { onTrimStart?($0) },
                    onEnd: { onTrimEnd?($0) }
                )
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .contentShape(Rectangle())
        .gesture(seekGesture, isEnabled: onSeek != nil)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityValue(isLoading ? "Loading" : "\(SessionLibraryLogic.formatPlaybackTime(duration)) long")
    }

    /// Tap or drag anywhere on the waveform to move the playback position.
    private var seekGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in seek(atX: value.location.x) }
    }

    private func seek(atX x: CGFloat) {
        guard width > 0 else { return }
        onSeek?(SessionLibraryLogic.time(xPosition: x, width: width, duration: duration))
    }
}

/// Dims the parts outside the range and shows a draggable handle at each edge (RF-5).
private struct TrimOverlay: View {
    let range: TrimRange
    let duration: TimeInterval
    let onStart: (TimeInterval) -> Void
    let onEnd: (TimeInterval) -> Void

    private let handleWidth: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startX = SessionLibraryLogic.xPosition(time: range.start, duration: duration, width: width)
            let endX = SessionLibraryLogic.xPosition(time: range.end, duration: duration, width: width)
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.45)).frame(width: max(startX, 0))
                Rectangle().fill(.black.opacity(0.45)).frame(width: max(width - endX, 0)).offset(x: endX)
                Rectangle()
                    .strokeBorder(.yellow, lineWidth: 2)
                    .frame(width: max(endX - startX, 2))
                    .offset(x: startX)
                    .allowsHitTesting(false)
                handle(atX: startX, width: width, onChange: onStart)
                handle(atX: endX, width: width, onChange: onEnd)
            }
        }
        .coordinateSpace(name: Self.space)
    }

    private func handle(atX x: CGFloat, width: CGFloat, onChange: @escaping (TimeInterval) -> Void) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.yellow)
            .frame(width: handleWidth)
            .overlay {
                Capsule().fill(.black.opacity(0.5)).frame(width: 2, height: 16)
            }
            // A wider invisible area makes the handle easy to grab on touch screens.
            .contentShape(Rectangle().inset(by: -10))
            .offset(x: x - handleWidth / 2)
            // High priority: dragging a handle must not scroll or start the back gesture.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        onChange(SessionLibraryLogic.time(xPosition: value.location.x, width: width, duration: duration))
                    }
            )
            .accessibilityHidden(true)
    }

    fileprivate static let space = "trimOverlay"
}

/// Vertical line at the playback position; the only part that redraws while playing.
private struct Playhead: View {
    @ObservedObject var progress: PlaybackProgress
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let x = SessionLibraryLogic.xPosition(time: progress.time, duration: duration, width: geometry.size.width)
            Rectangle()
                .fill(.primary)
                .frame(width: 2)
                .offset(x: x - 1)
        }
        .allowsHitTesting(false)
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
