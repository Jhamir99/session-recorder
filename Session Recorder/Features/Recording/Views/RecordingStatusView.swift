import SwiftUI

/// `REC`/`PAUSED`, elapsed time, file size and remaining time while a recording exists (RF-4).
struct RecordingStatusView: View {
    let state: RecordingState
    let liveInfo: RecordingLiveInfo

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                stateBadge
                Text(RecordingLogic.formatElapsed(liveInfo.elapsedSeconds))
                    .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isPaused ? .secondary : .primary)
            }

            HStack(spacing: 6) {
                Text(RecordingLogic.formatFileSize(liveInfo.fileSizeBytes))
                Text("·")
                Text(RecordingLogic.formatRemaining(liveInfo.remainingSeconds))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    private var stateBadge: some View {
        Text(isPaused ? "PAUSED" : "REC")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(isPaused ? Color.orange : Color.red, in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview("Recording") {
    RecordingStatusView(
        state: .recording,
        liveInfo: RecordingLiveInfo(elapsedSeconds: 3725, fileSizeBytes: 1_072_000_000, remainingSeconds: 5 * 3600)
    )
    .padding()
}

#Preview("Paused") {
    RecordingStatusView(
        state: .paused(.user),
        liveInfo: RecordingLiveInfo(elapsedSeconds: 125, fileSizeBytes: 36_000_000, remainingSeconds: 1500)
    )
    .padding()
}
