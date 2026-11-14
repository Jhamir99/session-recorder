import AVFoundation
import Foundation

/// Apple-API boundary for playing one session file (plan §3): `AVAudioPlayer` streams from disk,
/// so memory does not grow with the session length (NFR-3).
@MainActor
final class SessionPlayerService: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    /// Called when playback reaches the end.
    var onFinish: (() -> Void)?

    var isPlaying: Bool { player?.isPlaying ?? false }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    func load(url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
    }

    func play() {
        guard let player else { return }
        // At the end, start again from the beginning.
        if player.currentTime >= player.duration - 0.05 {
            player.currentTime = 0
        }
        player.play()
    }

    func pause() {
        player?.pause()
    }

    /// Stops playback and releases the file.
    func stop() {
        player?.stop()
        player = nil
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), player.duration)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.onFinish?()
        }
    }
}
