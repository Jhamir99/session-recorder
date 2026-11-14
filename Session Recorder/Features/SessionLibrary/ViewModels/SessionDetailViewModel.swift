import Combine
import Foundation
import os

/// Detail of one session (RF-2): info and waveform; playback and trim are added by later tasks.
@MainActor
final class SessionDetailViewModel: ObservableObject {
    @Published private(set) var session: SessionItem
    /// Grows while it is computed (left to right), complete when `isWaveformComplete`.
    @Published private(set) var waveform: WaveformData?
    @Published private(set) var isWaveformComplete = false

    private let waveformService: WaveformService
    private let logger = Logger(subsystem: "SessionRecorder", category: "SessionDetail")
    private var loadTask: Task<Void, Never>?

    init(session: SessionItem, waveformService: WaveformService = WaveformService()) {
        self.session = session
        self.waveformService = waveformService
    }

    deinit {
        loadTask?.cancel()
    }

    var audioInfo: SessionAudioInfo? { session.audioInfo }

    /// Reads the header if the list had not yet, then loads the waveform (cache or computed).
    func load() {
        guard loadTask == nil else { return }
        let url = session.url
        let service = waveformService
        loadTask = Task { [weak self] in
            if self?.session.audio == .loading {
                let state = await Task.detached(priority: .userInitiated) { SessionLibraryStore.readAudioState(at: url) }.value
                self?.session.audio = state
            }
            guard self?.session.audioInfo != nil else { return }
            let worker = Task.detached(priority: .userInitiated) {
                try service.waveform(for: url) { partial in
                    Task { @MainActor [weak self] in
                        guard self?.isWaveformComplete == false else { return }
                        self?.waveform = partial
                    }
                }
            }
            do {
                let complete = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                self?.waveform = complete
                self?.isWaveformComplete = true
            } catch {
                if !(error is CancellationError), (error as? WaveformService.WaveformError) != .cancelled {
                    self?.logger.error("Cannot load waveform: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    /// Stops loading when the detail closes.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }
}
