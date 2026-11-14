import SwiftUI

/// Play/pause, skip ±15 s and elapsed/total time (RF-2).
struct PlayerControlsView: View {
    @ObservedObject var progress: PlaybackProgress
    let duration: TimeInterval
    let isPlaying: Bool
    let isEnabled: Bool
    let onTogglePlayback: () -> Void
    let onSkip: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(SessionLibraryLogic.formatPlaybackTime(progress.time))
                Spacer()
                Text(SessionLibraryLogic.formatPlaybackTime(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack(spacing: 36) {
                Button("Back 15 Seconds", systemImage: "gobackward.15") {
                    onSkip(-SessionLibraryLogic.skipInterval)
                }
                .font(.title2)

                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                    onTogglePlayback()
                }
                .font(.system(size: 52))

                Button("Forward 15 Seconds", systemImage: "goforward.15") {
                    onSkip(SessionLibraryLogic.skipInterval)
                }
                .font(.title2)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
        }
        .disabled(!isEnabled)
    }
}

#Preview("Player") {
    PlayerControlsView(progress: PlaybackProgress(), duration: 3735, isPlaying: false, isEnabled: true,
                       onTogglePlayback: {}, onSkip: { _ in })
        .padding()
}
