import SwiftUI

/// One screen before the system permission prompt (spec RF-1, Decisions).
struct FirstUseExplanationView: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text("Record your sessions")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Session Recorder uses audio input to show levels and record from your mixer, audio interface or microphone.")
                    .multilineTextAlignment(.center)
                Text("Your recordings stay on this device.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 420)
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button(action: onContinue) {
                    Text("Continue")
                        .frame(maxWidth: 320)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Not Now", action: onNotNow)
                    .buttonStyle(.borderless)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 420)
        #endif
        .interactiveDismissDisabled()
    }
}

#Preview("Explanation") {
    FirstUseExplanationView(onContinue: {}, onNotNow: {})
}
