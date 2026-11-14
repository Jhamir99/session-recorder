import AVFoundation
import Foundation
import MediaPlayer

/// Apple-API boundary for playing one session file (plan §3). `AVPlayer` reads ahead and renders on its own
/// threads, so a busy main thread (e.g. a sheet or menu opening for the first time) does not interrupt the
/// audio, which happened with `AVAudioPlayer`. Memory does not grow with the session length (NFR-3).
/// Also publishes Now Playing info, handles the lock screen / Control Center / Mac media commands, and
/// reports audio interruptions (RF-2).
@MainActor
final class SessionPlayerService {
    /// Actions requested from outside the app (lock screen, Control Center, keyboard media keys).
    struct RemoteActions {
        var play: () -> Void
        var pause: () -> Void
        var skip: (TimeInterval) -> Void
        var seek: (TimeInterval) -> Void
    }

    private var player: AVPlayer?
    private var title = ""
    private(set) var duration: TimeInterval = 0
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    /// iOS: the system deactivated the session (call); it must be activated again before playing.
    private var needsSessionActivation = false
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    /// Called when playback reaches the end.
    var onFinish: (() -> Void)?
    /// Called when a call/another app or an unplugged headphone stops playback (no automatic resume).
    var onInterruption: (() -> Void)?

    var isPlaying: Bool { (player?.rate ?? 0) != 0 }

    var currentTime: TimeInterval {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else { return 0 }
        return min(max(seconds, 0), duration)
    }

    init() {
        observeInterruptions()
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        if let endObserver { center.removeObserver(endObserver) }
    }

    /// `duration` comes from the file header (already read for the detail).
    func load(url: URL, title: String, duration: TimeInterval) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        // Local file: start as soon as play is requested, no network-style buffering wait.
        player.automaticallyWaitsToMinimizeStalling = false
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlaying()
                self?.onFinish?()
            }
        }
        self.player = player
        self.title = title
        self.duration = duration
    }

    /// The session was renamed while open: Now Playing shows the new name. The open file keeps playing.
    func updateTitle(_ title: String) {
        self.title = title
        updateNowPlaying()
    }

    func play() {
        guard let player else { return }
        // At the end, start again from the beginning.
        if currentTime >= duration - 0.05 {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        updateNowPlaying()
    }

    /// Stops playback, releases the file and clears Now Playing.
    func stop() {
        player?.pause()
        player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        deactivateRemoteControls()
    }

    /// Exact seek (no tolerance), so the playhead and trim times match the audio.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = CMTime(seconds: min(max(time, 0), duration), preferredTimescale: 48_000)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }

    // MARK: Now Playing and remote commands (RF-2)

    /// Shows the session in Now Playing and routes the media commands to `actions` until `stop()`.
    func activateRemoteControls(_ actions: RemoteActions) {
        deactivateRemoteControls()
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ handler: @escaping @MainActor (MPRemoteCommandEvent) -> Void) {
            command.isEnabled = true
            // Media commands arrive on the main thread; hop explicitly so the isolation is guaranteed.
            let target = command.addTarget { event in
                nonisolated(unsafe) let event = event
                Task { @MainActor in handler(event) }
                return .success
            }
            remoteTargets.append((command, target))
        }
        add(center.playCommand) { _ in actions.play() }
        add(center.pauseCommand) { _ in actions.pause() }
        add(center.togglePlayPauseCommand) { [weak self] _ in
            (self?.isPlaying ?? false) ? actions.pause() : actions.play()
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: SessionLibraryLogic.skipInterval)]
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: SessionLibraryLogic.skipInterval)]
        add(center.skipBackwardCommand) { _ in actions.skip(-SessionLibraryLogic.skipInterval) }
        add(center.skipForwardCommand) { _ in actions.skip(SessionLibraryLogic.skipInterval) }
        add(center.changePlaybackPositionCommand) { event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                actions.seek(event.positionTime)
            }
        }
        updateNowPlaying()
    }

    private func deactivateRemoteControls() {
        for (command, target) in remoteTargets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        remoteTargets = []
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = nil
        #if os(macOS)
        info.playbackState = .stopped
        #endif
    }

    private func updateNowPlaying() {
        guard player != nil, !remoteTargets.isEmpty else { return }
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Session Recorder",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        #if os(macOS)
        info.playbackState = isPlaying ? .playing : .paused
        #endif
    }

    // MARK: Interruptions (RF-2)

    private func observeInterruptions() {
        #if os(iOS)
        let center = NotificationCenter.default
        // A call or another app took the audio (iOS 27 API; the player is already paused by the system).
        observers.append(center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: .main) {
            [weak self] notification in
            guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext,
                  context.source == .system else { return }
            Task { @MainActor [weak self] in self?.interrupted() }
        })
        // Headphones or another output unplugged: pause instead of playing through the speaker.
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) {
            [weak self] notification in
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in self?.interrupted() }
        })
        #endif
    }

    /// Call before `play()`: after an interruption the session is reactivated (off the main thread,
    /// session calls can block).
    func prepareToResume() async {
        #if os(iOS)
        guard needsSessionActivation else { return }
        needsSessionActivation = false
        await Task.detached(priority: .userInitiated) {
            try? AVAudioSession.sharedInstance().setActive(true)
        }.value
        #endif
    }

    private func interrupted() {
        guard let player, isPlaying || remoteTargets.isEmpty == false else { return }
        needsSessionActivation = true
        player.pause()
        updateNowPlaying()
        onInterruption?()
    }
}
