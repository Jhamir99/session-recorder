import SwiftUI

/// Record (idle) or Pause/Resume + Stop (recording/paused) (RF-3, RF-5, RF-6).
struct RecordingControlsView: View {
    let state: RecordingState
    let canRecord: Bool
    let canResume: Bool
    let onRecord: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            switch state {
            case .idle:
                controlButton("Record", systemImage: "record.circle.fill", tint: .red, size: 76, action: onRecord)
                    .disabled(!canRecord)
            case .recording:
                controlButton("Pause", systemImage: "pause.circle.fill", tint: .primary, size: 64, action: onPause)
                controlButton("Stop", systemImage: "stop.circle.fill", tint: .red, size: 64, action: onStop)
            case .paused:
                controlButton("Resume", systemImage: "record.circle.fill", tint: .red, size: 64, action: onResume)
                    .disabled(!canResume)
                controlButton("Stop", systemImage: "stop.circle.fill", tint: .primary, size: 64, action: onStop)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: size))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

#Preview("Idle") {
    RecordingControlsView(state: .idle, canRecord: true, canResume: false,
                          onRecord: {}, onPause: {}, onResume: {}, onStop: {})
}

#Preview("Idle, cannot record") {
    RecordingControlsView(state: .idle, canRecord: false, canResume: false,
                          onRecord: {}, onPause: {}, onResume: {}, onStop: {})
}

#Preview("Recording") {
    RecordingControlsView(state: .recording, canRecord: false, canResume: false,
                          onRecord: {}, onPause: {}, onResume: {}, onStop: {})
}

#Preview("Paused") {
    RecordingControlsView(state: .paused(.user), canRecord: false, canResume: true,
                          onRecord: {}, onPause: {}, onResume: {}, onStop: {})
}
