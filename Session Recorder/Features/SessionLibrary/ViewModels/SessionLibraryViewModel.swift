import Combine
import Foundation

/// Session list state (RF-1): sessions newest first, selection, and later rename/delete (RF-3, RF-4).
@MainActor
final class SessionLibraryViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionItem] = []
    /// False until the first listing finished (avoids flashing the empty state).
    @Published private(set) var hasLoaded = false
    @Published var selectedSessionID: SessionItem.ID?

    private let store: SessionLibraryStore
    /// Increases on every refresh so results of an older refresh are ignored.
    private var refreshGeneration = 0
    private var audioInfoTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private weak var recording: RecordingViewModel?

    init(store: SessionLibraryStore = SessionLibraryStore()) {
        self.store = store
    }

    /// Refreshes the list whenever a recording is saved or recovered (RF-1). Safe to call more than once.
    func attach(recording: RecordingViewModel) {
        guard self.recording !== recording else { return }
        self.recording = recording
        recording.sessionSaved
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    var selectedSession: SessionItem? {
        sessions.first { $0.id == selectedSessionID }
    }

    /// Lists the folder off the main thread, then reads durations/formats (NFR-2).
    /// Audio info already known for an unchanged file is kept, so rows do not flicker.
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        let store = store
        let known = Dictionary(sessions.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
        audioInfoTask?.cancel()
        audioInfoTask = Task { [weak self] in
            let listed = await Task.detached(priority: .userInitiated) { store.listSessions() }.value
            guard let self, generation == refreshGeneration else { return }
            sessions = listed.map { item in
                guard let previous = known[item.url], previous.fileSizeBytes == item.fileSizeBytes,
                      previous.audio != .loading else { return item }
                var kept = item
                kept.audio = previous.audio
                return kept
            }
            hasLoaded = true
            if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
                self.selectedSessionID = nil
            }
            await loadAudioInfo(generation: generation)
        }
    }

    /// Reads headers one by one in the background and updates each row as soon as it is known.
    private func loadAudioInfo(generation: Int) async {
        let pending = sessions.filter { $0.audio == .loading }.map(\.url)
        for url in pending {
            guard !Task.isCancelled else { return }
            let state = await Task.detached(priority: .utility) { SessionLibraryStore.readAudioState(at: url) }.value
            guard generation == refreshGeneration, let index = sessions.firstIndex(where: { $0.url == url }) else { continue }
            sessions[index].audio = state
        }
    }
}
