import SwiftUI

/// **Session** menu with keyboard shortcuts (RF-8): Mac menu bar, and iPad with a hardware keyboard.
/// Acts on the focused window's selected session and its detail.
struct SessionLibraryCommands: Commands {
    @FocusedObject private var library: SessionLibraryViewModel?
    @FocusedObject private var recording: RecordingViewModel?

    private var detail: SessionDetailViewModel? { library?.activeDetail }

    var body: some Commands {
        CommandMenu("Session") {
            // No shortcut here: Space is handled by the single Space item in the Recording menu (two items with
            // the same key equivalent made the Mac ignore both).
            Button("Play/Pause") {
                detail?.togglePlaybackFromKeyboard()
            }
            .disabled(!canControlPlayback)

            Button("Back 15 Seconds") {
                detail?.skip(by: -SessionLibraryLogic.skipInterval)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(!canControlPlayback)

            Button("Forward 15 Seconds") {
                detail?.skip(by: SessionLibraryLogic.skipInterval)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(!canControlPlayback)

            Divider()

            Button("Rename…") {
                if let session = library?.selectedSession { library?.startRename(session) }
            }
            .disabled(!canActOnSelection)

            Button("Share…") {
                if let session = library?.selectedSession { library?.startShare(session) }
            }
            .disabled(!canActOnSelection || library?.selectedSession?.isUnreadable == true)

            #if os(macOS)
            Button("Show in Finder") {
                if let session = library?.selectedSession { SessionLibraryStore.revealInFinder(session.url) }
            }
            .disabled(!canActOnSelection)
            #endif

            Divider()

            // ⌘⌫ asks for confirmation like the other delete actions (RF-4).
            Button(deleteTitle) {
                if let session = library?.selectedSession { library?.requestDelete(session) }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(!canActOnSelection)
        }
    }

    private var hasOpenDialog: Bool {
        library?.hasOpenDialog == true
    }

    private var canControlPlayback: Bool {
        library?.canControlPlayback(isRecordingActive: recording?.state.hasActiveRecording == true) == true
    }

    /// A session is selected in the focused window and nothing modal is open (not while trimming).
    private var canActOnSelection: Bool {
        library?.selectedSession != nil && !hasOpenDialog && detail?.isTrimming != true
    }

    private var deleteTitle: String {
        SessionLibraryStore.deleteMovesToTrash
            ? String(localized: "Move to Trash", comment: "Session menu")
            : String(localized: "Delete…", comment: "Session menu")
    }
}
