import Combine
import Foundation

/// Session list state (RF-1): sessions newest first, selection, and later rename/delete (RF-3, RF-4).
@MainActor
final class SessionLibraryViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionItem] = []
    /// False until the first listing finished (avoids flashing the empty state).
    @Published private(set) var hasLoaded = false
    @Published var selectedSessionID: SessionItem.ID?
    /// Session whose rename sheet is open (RF-3).
    @Published var renamingSession: SessionItem?
    /// Session whose share sheet is open (RF-6).
    @Published var sharingSession: SessionItem?
    /// Detail shown in this window (set by the detail view); the Session menu controls its playback.
    @Published private(set) var activeDetail: SessionDetailViewModel?
    /// An export is running: on Mac the whole window is darkened behind the progress card.
    @Published var isExportInProgress = false
    /// Session waiting for delete confirmation (RF-4).
    @Published var deletingSession: SessionItem?
    /// Shown as an alert when a file operation fails.
    @Published var notice: LibraryNotice?

    private let store: SessionLibraryStore
    /// Increases on every refresh so results of an older refresh are ignored.
    private var refreshGeneration = 0
    private var audioInfoTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private weak var recording: RecordingViewModel?
    private var activeDetailObservation: AnyCancellable?
    /// Stops the playback that currently owns the audio session (nil when nothing plays).
    private var stopActivePlayback: (@MainActor () -> Void)?

    /// Exports left by an earlier run are removed once per launch (RF-6).
    private static var hasRemovedLeftoverExports = false

    init(store: SessionLibraryStore = SessionLibraryStore()) {
        self.store = store
        if !Self.hasRemovedLeftoverExports {
            Self.hasRemovedLeftoverExports = true
            Task.detached(priority: .utility) { SessionExportService().removeAllExports() }
        }
    }

    /// Refreshes the list whenever a recording is saved or recovered (RF-1). Safe to call more than once.
    func attach(recording: RecordingViewModel) {
        guard self.recording !== recording else { return }
        self.recording = recording
        recording.sessionSaved
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    // MARK: Playback hand-off (RF-2)

    /// Playback stops recording meters and switches the audio session; ending restores both.
    var playbackHandoff: PlaybackHandoff {
        PlaybackHandoff(
            begin: { [weak self] stop in await self?.beginPlayback(stop: stop) },
            end: { [weak self] in await self?.endPlayback() }
        )
    }

    /// Stops any playback (Record tab selected, recording started).
    func stopPlayback() {
        stopActivePlayback?()
    }

    private func beginPlayback(stop: @escaping @MainActor () -> Void) async {
        let isFirst = stopActivePlayback == nil
        stopActivePlayback = stop
        guard isFirst else { return }
        recording?.setPlaybackActive(true)
        await recording?.audioSource?.service.setPlaybackMode(true)
    }

    private func endPlayback() async {
        guard stopActivePlayback != nil else { return }
        stopActivePlayback = nil
        await recording?.audioSource?.service.setPlaybackMode(false)
        // Another playback may have started meanwhile; keep the meters stopped then.
        if stopActivePlayback == nil {
            recording?.setPlaybackActive(false)
        }
    }

    // MARK: Rename (RF-3)

    func startRename(_ session: SessionItem) {
        renamingSession = session
    }

    /// Live validation for the rename sheet: trimmed name, or why it cannot be used.
    func validateRename(_ text: String, for session: SessionItem) -> Result<String, RenameError> {
        SessionLibraryLogic.validateRename(text, currentName: session.name, existingNames: Set(sessions.map(\.name)))
    }

    /// Renames the file; the row and the selection follow the new name. False if it was not renamed.
    @discardableResult
    func rename(_ session: SessionItem, to text: String) -> Bool {
        guard case .success(let name) = validateRename(text, for: session) else { return false }
        do {
            let newURL = try store.rename(session.url, to: name)
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index].url = newURL
                sessions[index].name = name
            }
            // The ID (file identifier) is kept, so the selection and an open detail stay as they are.
            renamingSession = nil
            refresh()
            return true
        } catch {
            notice = LibraryNotice(kind: .operationFailed("Renaming"))
            refresh()
            return false
        }
    }

    // MARK: Trim (RF-5)

    /// Unique names come from the current list; the saved session is listed and opened.
    var trimContext: TrimContext {
        TrimContext(
            existingNames: { [weak self] in Set(self?.sessions.map(\.name) ?? []) },
            didSave: { [weak self] url in self?.refresh(selecting: url) }
        )
    }

    // MARK: Share (RF-6)

    func startShare(_ session: SessionItem) {
        sharingSession = session
    }

    // MARK: Delete (RF-4)

    /// Asks for confirmation first (the dialog names the session).
    func requestDelete(_ session: SessionItem) {
        deletingSession = session
    }

    func delete(_ session: SessionItem) {
        deletingSession = nil
        // Stop playback before the file goes away (it may be the playing session).
        if selectedSessionID == session.id {
            stopPlayback()
        }
        do {
            try store.delete(session.url)
            sessions.removeAll { $0.id == session.id }
            if selectedSessionID == session.id {
                selectedSessionID = nil
            }
        } catch {
            notice = LibraryNotice(kind: .operationFailed("Deleting"))
        }
        refresh()
    }

    func detailDidAppear(_ detail: SessionDetailViewModel) {
        activeDetail = detail
        // Menus observe the library: forward detail changes (player ready, playing) so they update.
        activeDetailObservation = detail.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    func detailDidDisappear(_ detail: SessionDetailViewModel) {
        guard activeDetail === detail else { return }
        activeDetail = nil
        activeDetailObservation = nil
    }

    /// Playback shortcuts (Space, ⌘← / ⌘→) are possible: a detail is open, no recording, no dialog (RF-8).
    func canControlPlayback(isRecordingActive: Bool) -> Bool {
        guard let activeDetail, !hasOpenDialog, !isRecordingActive else { return false }
        return activeDetail.canPlay
    }

    /// A sheet or dialog is open (rename, share, delete): keyboard shortcuts must not act behind it (RF-8).
    var hasOpenDialog: Bool {
        renamingSession != nil || sharingSession != nil || deletingSession != nil
    }

    var selectedSession: SessionItem? {
        sessions.first { $0.id == selectedSessionID }
    }

    /// Lists the folder off the main thread, then reads durations/formats (NFR-2).
    /// Audio info already known for an unchanged file is kept, so rows do not flicker.
    /// `selecting`: a file to select once listed (e.g. a new trimmed session).
    func refresh(selecting urlToSelect: URL? = nil) {
        refreshGeneration += 1
        let generation = refreshGeneration
        let store = store
        let known = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        audioInfoTask?.cancel()
        audioInfoTask = Task { [weak self] in
            let listed = await Task.detached(priority: .userInitiated) { store.listSessions() }.value
            guard let self, generation == refreshGeneration else { return }
            sessions = listed.map { item in
                guard let previous = known[item.id], previous.fileSizeBytes == item.fileSizeBytes,
                      previous.audio != .loading else { return item }
                var kept = item
                kept.audio = previous.audio
                return kept
            }
            hasLoaded = true
            if let urlToSelect, let item = sessions.first(where: { $0.url.standardizedFileURL == urlToSelect.standardizedFileURL }) {
                selectedSessionID = item.id
            } else if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = nil
            }
            await loadAudioInfo(generation: generation)
        }
    }

    /// Reads headers in the background in batches and applies each batch at once, so the list is not
    /// recomputed once per session.
    private func loadAudioInfo(generation: Int) async {
        let pending = sessions.filter { $0.audio == .loading }.map(\.url)
        let batchSize = 25
        for start in stride(from: 0, to: pending.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let batch = Array(pending[start..<min(start + batchSize, pending.count)])
            let states = await Task.detached(priority: .utility) {
                batch.map { ($0, SessionLibraryStore.readAudioState(at: $0)) }
            }.value
            guard generation == refreshGeneration else { return }
            var updated = sessions
            for (url, state) in states {
                if let index = updated.firstIndex(where: { $0.url == url }) {
                    updated[index].audio = state
                }
            }
            sessions = updated
        }
    }
}
