import AVFoundation
import Foundation
import MediaPlayer

/// Apple-API boundary for playing one session file (plan §3): `AVAudioPlayer` streams from disk, so memory
/// does not grow with the session length (NFR-3). Also publishes Now Playing info, handles the lock screen /
/// Control Center / Mac media commands, and reports audio interruptions (RF-2).
@MainActor
final class SessionPlayerService: NSObject, AVAudioPlayerDelegate {
    /// Actions requested from outside the app (lock screen, Control Center, keyboard media keys).
    struct RemoteActions {
        var play: () -> Void
        var pause: () -> Void
        var skip: (TimeInterval) -> Void
        var seek: (TimeInterval) -> Void
    }

    private var player: AVAudioPlayer?
    private var title = ""
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    /// iOS: the system deactivated the session (call); it must be activated again before playing.
    private var needsSessionActivation = false
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    /// Called when playback reaches the end.
    var onFinish: (() -> Void)?
    /// Called when a call/another app or an unplugged headphone stops playback (no automatic resume).
    var onInterruption: (() -> Void)?

    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    override init() {
        super.init()
        observeInterruptions()
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
    }

    func load(url: URL, title: String) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        self.title = title
    }

    func play() {
        guard let player else { return }
        // At the end, start again from the beginning.
        if player.currentTime >= player.duration - 0.05 {
            player.currentTime = 0
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
        player?.stop()
        player = nil
        deactivateRemoteControls()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), player.duration)
        updateNowPlaying()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.updateNowPlaying()
            self?.onFinish?()
        }
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
        guard let player, !remoteTargets.isEmpty else { return }
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Session Recorder",
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]
        #if os(macOS)
        info.playbackState = player.isPlaying ? .playing : .paused
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
        guard let player, player.isPlaying || remoteTargets.isEmpty == false else { return }
        needsSessionActivation = true
        player.pause()
        updateNowPlaying()
        onInterruption?()
    }
}
