import Foundation

extension AudioSourceSelectionViewModel {
    convenience init(previewState: PreviewState) {
        self.init(
            service: AudioInputDeviceService(),
            store: AudioDeviceSelectionRepository(
                defaults: UserDefaults(suiteName: "preview.audio.devices") ?? .standard,
                storageKey: "preview_unused"
            )
        )
        cancellables.removeAll()
        devices = previewState.devices
        selectedDeviceID = previewState.selectedDeviceID
        permissionState = previewState.permissionState
        selectedMode = previewState.selectedMode
        displayedChannels = previewState.displayedChannels
        activeSelection = previewState.activeSelection
        stereoLeftCandidateID = previewState.stereoLeftCandidateID
        userMessage = previewState.userMessage
        showsPermissionPrompt = previewState.showsPermissionPrompt
        hasNoEligibleDevices = previewState.hasNoEligibleDevices
        rawDevices = previewState.rawDevices
    }

    struct PreviewState {
        var devices: [AudioDeviceSelectionHelper.DisambiguatedDevice] = []
        var selectedDeviceID: String?
        var permissionState: AudioInputPermissionState = .unknown
        var selectedMode: AudioChannelMode = .mono
        var displayedChannels: [AudioInputChannel] = []
        var activeSelection: ChannelSelection?
        var stereoLeftCandidateID: String?
        var userMessage: AudioSourceUserMessage?
        var showsPermissionPrompt: Bool = false
        var hasNoEligibleDevices: Bool = false
        var rawDevices: [AudioInputDevice] = []
    }
}
