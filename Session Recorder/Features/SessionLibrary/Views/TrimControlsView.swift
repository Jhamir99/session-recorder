import SwiftUI

/// Trim mode controls (RF-5): exact start/end/duration and playing the selection.
/// Cancel and Save are in the navigation bar while trimming.
struct TrimControlsView: View {
    let range: TrimRange
    let canPlay: Bool
    let isPlaying: Bool
    let onPlaySelection: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                timeColumn("Start", SessionLibraryLogic.formatTrimTime(range.start), alignment: .leading)
                Spacer()
                timeColumn("Duration", SessionLibraryLogic.formatTrimTime(range.duration), alignment: .center)
                Spacer()
                timeColumn("End", SessionLibraryLogic.formatTrimTime(range.end), alignment: .trailing)
            }

            Button(isPlaying ? String(localized: "Pause", comment: "Trim") : String(localized: "Play Selection", comment: "Trim"),
                   systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill",
                   action: onPlaySelection)
                .labelStyle(.iconOnly)
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .buttonStyle(.plain)
                .disabled(!canPlay)

            if range.duration < SessionLibraryLogic.minimumTrimDuration {
                Text("The selection must be at least 1 second long.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text("Save creates a new session. The original is kept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timeColumn(_ title: LocalizedStringKey, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Trim") {
    TrimControlsView(range: TrimRange(start: 12.3, end: 3605.7), canPlay: true, isPlaying: false, onPlaySelection: {})
        .padding()
}
