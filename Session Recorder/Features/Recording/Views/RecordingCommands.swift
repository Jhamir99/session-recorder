import SwiftUI

/// Opens the source sheet on the Record tab of a window. Equal per window, so publishing a new closure
/// on every view update does not invalidate the menu.
struct ChooseRecordingSourceAction: Equatable {
    let windowID: UUID
    let perform: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.windowID == rhs.windowID }
}

extension FocusedValues {
    /// Set by ContentView for the focused window.
    @Entry var chooseRecordingSource: ChooseRecordingSourceAction?
}

/// **Recording** menu with keyboard shortcuts (RF-9): Mac menu bar, and iPad with a hardware keyboard.
/// Acts on the recording of the focused window.
struct RecordingCommands: Commands {
    @FocusedObject private var recording: RecordingViewModel?
    @FocusedValue(\.chooseRecordingSource) private var chooseSource

    var body: some Commands {
        CommandMenu("Recording") {
            // ⌘R records when idle and stops while recording or paused.
            Button(isActive ? "Stop" : "Record") {
                guard let recording else { return }
                if recording.state.hasActiveRecording {
                    recording.stopRecording()
                } else {
                    recording.startRecording()
                }
            }
            .keyboardShortcut("r")
            .disabled(!(isActive || recording?.canRecord == true))

            // Space without modifiers. The app has no text fields yet; when one is added (e.g. rename in the
            // session library), check that typing a space there does not pause the recording (RF-9).
            Button(isPaused ? "Resume" : "Pause") {
                guard let recording else { return }
                if isPaused {
                    recording.resumeRecording()
                } else {
                    recording.pauseRecording()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!(recording?.state == .recording || recording?.canResume == true))

            Divider()

            Button("Choose Source…") {
                chooseSource?.perform()
            }
            .disabled(chooseSource == nil || recording == nil || isActive)
        }
    }

    private var isActive: Bool {
        recording?.state.hasActiveRecording == true
    }

    private var isPaused: Bool {
        if case .paused = recording?.state { return true }
        return false
    }
}
