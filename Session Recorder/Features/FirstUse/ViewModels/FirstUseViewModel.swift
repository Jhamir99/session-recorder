import Combine
import Foundation

/// First use (spec RF-1–RF-3): shows the explanation once while access is undecided, asks for access only
/// after a user action, and offers the right action when access is not allowed.
@MainActor
final class FirstUseViewModel: ObservableObject {
    @Published var isShowingExplanation = false

    private let settings: FirstUseSettingsRepository
    private weak var audioSource: AudioSourceSelectionViewModel?

    init(settings: FirstUseSettingsRepository? = nil) {
        self.settings = settings ?? FirstUseSettingsRepository()
    }

    /// Called once the window appears; shows the explanation on first use (RF-1).
    func attach(audioSource: AudioSourceSelectionViewModel) {
        guard self.audioSource !== audioSource else { return }
        self.audioSource = audioSource
        isShowingExplanation = AudioAccessLogic.showsExplanation(
            access: access(for: audioSource.permissionState),
            wasExplained: settings.wasExplained
        )
    }

    func access(for permission: AudioInputPermissionState) -> AudioAccessState {
        AudioAccessLogic.accessState(for: permission)
    }

    /// Continue: close the explanation, then show the system prompt (RF-1, RF-2).
    func continueFromExplanation() {
        settings.markExplained()
        isShowingExplanation = false
        requestAccess()
    }

    /// Not Now: close without asking; the Record tab offers Allow Audio Input (RF-1, RF-3).
    func dismissExplanation() {
        settings.markExplained()
        isShowingExplanation = false
    }

    func requestAccess() {
        guard let audioSource else { return }
        Task { await audioSource.requestAccess() }
    }

    func openSettings() {
        SystemSettingsLink.openAudioInputSettings()
    }
}
