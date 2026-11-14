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
    @FocusedObject private var library: SessionLibraryViewModel?
    @FocusedValue(\.chooseRecordingSource) private var chooseSource

    var body: some Commands {
        CommandMenu("Recording") {
            // ⌘R records when idle and stops while recording or paused.
            Button(isActive ? String(localized: "Stop", comment: "Recording menu") : String(localized: "Record", comment: "Recording menu")) {
                guard let recording else { return }
                if recording.state.hasActiveRecording {
                    recording.stopRecording()
                } else {
                    recording.startRecording()
                }
            }
            .keyboardShortcut("r")
            .disabled(!(isActive || recording?.canRecord == true))

            // The app's only Space shortcut (two menu items with the same key equivalent made the Mac ignore
            // both): pause/resume while a recording exists, otherwise play/pause the open session (library RF-8).
            // Disabled while a library dialog with a text field is open, so typing a space never acts (RF-9).
            Button(spaceTitle) {
                if isActive {
                    recording?.togglePauseFromKeyboard()
                } else {
                    library?.activeDetail?.togglePlaybackFromKeyboard()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!isSpaceEnabled)

            Divider()

            Button("Choose Source…") {
                chooseSource?.perform()
            }
            .disabled(chooseSource == nil || recording == nil || isActive)
        }
    }

    private var spaceTitle: String {
        if isActive {
            return isPaused ? String(localized: "Resume", comment: "Recording menu") : String(localized: "Pause", comment: "Recording menu")
        }
        return canControlPlayback
            ? String(localized: "Play/Pause Session", comment: "Recording menu: Space plays the open session")
            : String(localized: "Pause", comment: "Recording menu")
    }

    private var canControlPlayback: Bool {
        library?.canControlPlayback(isRecordingActive: isActive) == true
    }

    private var isSpaceEnabled: Bool {
        guard library?.hasOpenDialog != true else { return false }
        if isActive {
            return recording?.state == .recording || recording?.canResume == true
        }
        return canControlPlayback
    }

    private var isActive: Bool {
        recording?.state.hasActiveRecording == true
    }

    private var isPaused: Bool {
        if case .paused = recording?.state { return true }
        return false
    }
}

#if os(macOS)
import AppKit

/// Mac: handles Space at the window level. Keys without ⌘ go to the focused view first (sidebar, session
/// list…), which used Space itself, so the menu's Space shortcut never fired. Space is ignored while a text
/// field is being edited (e.g. renaming), so typing a space never pauses or plays (RF-9, library RF-8).
struct SpaceKeyHandler: NSViewRepresentable {
    /// Returns true when Space was used (pause/resume recording or play/pause the open session).
    let onSpace: () -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.onSpace = onSpace
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSpace: onSpace)
    }

    @MainActor
    final class Coordinator {
        var onSpace: () -> Bool
        weak var view: NSView?
        private var monitor: Any?

        init(onSpace: @escaping () -> Bool) {
            self.onSpace = onSpace
        }

        func install() {
            // Local monitors run on the main thread.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                nonisolated(unsafe) let event = event
                let handled = MainActor.assumeIsolated { self.handles(event) }
                return handled ? nil : event
            }
        }

        func uninstall() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// True when the event was a plain Space for this window and it was used.
        private func handles(_ event: NSEvent) -> Bool {
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard event.keyCode == 49, modifiers.isEmpty, !event.isARepeat,
                  let window = view?.window, event.window === window,
                  !(window.firstResponder is NSText) else { return false }
            return onSpace()
        }
    }
}
#endif
