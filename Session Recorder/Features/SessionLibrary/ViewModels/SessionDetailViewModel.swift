import Combine
import Foundation
import os

/// Playback position (~20 updates per second while playing). Kept out of `SessionDetailViewModel` so only
/// the playhead and time labels redraw at that rate (same reason as the recording meters).
@MainActor
final class PlaybackProgress: ObservableObject {
    @Published fileprivate(set) var time: TimeInterval = 0
}

/// Detail of one session (RF-2): info, waveform and playback; trim is added by a later task.
@MainActor
final class SessionDetailViewModel: ObservableObject {
    @Published private(set) var session: SessionItem
    /// Grows while it is computed (left to right), complete when `isWaveformComplete`.
    @Published private(set) var waveform: WaveformData?
    @Published private(set) var isWaveformComplete = false
    @Published private(set) var isPlaying = false
    /// False when the player could not open the file.
    @Published private(set) var isPlayable = false
    /// A recording exists: playback is disabled so it never affects the recording (RF-2).
    @Published private(set) var isPlaybackBlocked = false
    let progress = PlaybackProgress()

    private let waveformService: WaveformService
    private let logger = Logger(subsystem: "SessionRecorder", category: "SessionDetail")
    private var loadTask: Task<Void, Never>?
    private let player = SessionPlayerService()
    private var progressTask: Task<Void, Never>?
    private let handoff: PlaybackHandoff
    /// The audio session is set up for playback (until playback is stopped).
    private var ownsPlayback = false

    init(session: SessionItem, waveformService: WaveformService = WaveformService(), handoff: PlaybackHandoff? = nil) {
        self.session = session
        self.waveformService = waveformService
        self.handoff = handoff ?? .none
        player.onFinish = { [weak self] in self?.playbackStopped() }
    }

    deinit {
        loadTask?.cancel()
        progressTask?.cancel()
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
            self?.preparePlayer()
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

    /// Stops loading and playback when the detail closes (RF-2).
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        stopPlayback()
    }

    // MARK: Playback (RF-2)

    var duration: TimeInterval { audioInfo?.duration ?? 0 }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    var canPlay: Bool { isPlayable && !isPlaybackBlocked }

    /// Switches the audio session to playback first (stops recording meters), then plays.
    func play() {
        guard canPlay else { return }
        Task { [weak self] in
            guard let self else { return }
            if !ownsPlayback {
                ownsPlayback = true
                await handoff.begin { [weak self] in self?.stopPlayback() }
            }
            guard ownsPlayback, canPlay else { return }
            player.play()
            isPlaying = player.isPlaying
            startProgressUpdates()
        }
    }

    /// Recording started or ended (RF-2): playback stops and stays disabled while a recording exists.
    func setPlaybackBlocked(_ blocked: Bool) {
        guard isPlaybackBlocked != blocked else { return }
        isPlaybackBlocked = blocked
        if blocked {
            stopPlayback()
        } else if session.audioInfo != nil {
            preparePlayer()
        }
    }

    func pause() {
        player.pause()
        playbackStopped()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: player.currentTime + seconds)
    }

    func seek(to time: TimeInterval) {
        guard canPlay else { return }
        player.seek(to: time)
        progress.time = player.currentTime
    }

    /// Stops and releases the player; the audio session goes back to recording.
    /// The player is prepared again when the detail loads (e.g. coming back to the tab).
    func stopPlayback() {
        player.stop()
        playbackStopped()
        isPlayable = false
        guard ownsPlayback else { return }
        ownsPlayback = false
        let handoff = handoff
        Task { await handoff.end() }
    }

    private func preparePlayer() {
        do {
            try player.load(url: session.url)
            isPlayable = true
        } catch {
            logger.error("Cannot open player: \(error.localizedDescription, privacy: .public)")
            isPlayable = false
        }
    }

    private func playbackStopped() {
        isPlaying = false
        progressTask?.cancel()
        progressTask = nil
        progress.time = player.currentTime
    }

    private func updateProgress() {
        progress.time = player.currentTime
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            // `self` is not kept across the sleep, so a closed detail is released.
            while !Task.isCancelled {
                self?.updateProgress()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
