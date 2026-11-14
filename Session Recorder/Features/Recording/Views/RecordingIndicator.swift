import SwiftUI

/// Compact `REC`/`PAUSED` + elapsed time shown outside the Record tab while a recording exists (RF-4).
/// Tapping it returns to the Record tab.
struct RecordingIndicator: View {
    let state: RecordingState
    let elapsedSeconds: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isPaused ? "pause.circle.fill" : "record.circle.fill")
                    .foregroundStyle(isPaused ? Color.orange : Color.red)
                (isPaused ? Text("PAUSED", comment: "Recording state badge") : Text(verbatim: "REC"))
                    .font(.subheadline.weight(.bold))
                Text(RecordingLogic.formatElapsed(elapsedSeconds))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Back to recording")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isPaused
                ? String(localized: "Recording paused, \(RecordingLogic.formatElapsed(elapsedSeconds))", comment: "VoiceOver: Sessions tab indicator")
                : String(localized: "Recording, \(RecordingLogic.formatElapsed(elapsedSeconds))", comment: "VoiceOver: Sessions tab indicator")
        )
        .accessibilityHint("Returns to the Record tab.")
        .accessibilityAddTraits(.isButton)
    }

    private var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }
}

#Preview("Recording") {
    RecordingIndicator(state: .recording, elapsedSeconds: 3725, onTap: {})
        .padding()
}

#Preview("Paused") {
    RecordingIndicator(state: .paused(.user), elapsedSeconds: 125, onTap: {})
        .padding()
}
