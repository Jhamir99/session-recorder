import Combine
import Foundation

@MainActor
final class AudioSourceSelectionViewModel: ObservableObject {
    @Published var devices: [AudioDeviceSelectionHelper.DisambiguatedDevice] = []
    @Published var selectedDeviceID: String?
    @Published var permissionState: AudioInputPermissionState = .unknown
    @Published var selectedMode: AudioChannelMode = .mono
    @Published var displayedChannels: [AudioInputChannel] = []
    @Published var activeSelection: ChannelSelection?
    @Published var stereoLeftCandidateID: String?
    @Published var userMessage: AudioSourceUserMessage?
    @Published var showsPermissionPrompt: Bool = false
    @Published var hasNoEligibleDevices: Bool = false

    let service: AudioInputDeviceService
    let store: AudioDeviceSelectionRepository
    var cancellables: Set<AnyCancellable> = []
    var rawDevices: [AudioInputDevice] = []
    var lastValidMonoByDevice: [String: String] = [:]
    var lastValidStereoByDevice: [String: (left: String, right: String)] = [:]

    // Automatic device selection state (RF-7).
    var hasAppliedLaunchSelection = false
    /// Device that disconnected and was replaced by a fallback; selected again if it reconnects.
    var replacedDeviceID: String?
    var userChangedSourceManually = false
    /// Set by the future recording feature: while true, the source never changes automatically.
    var isSourceLocked = false

    init(service: AudioInputDeviceService? = nil, store: AudioDeviceSelectionRepository? = nil) {
        self.service = service ?? AudioInputDeviceService()
        self.store = store ?? AudioDeviceSelectionRepository()
        bindService()
        refreshFromService()
    }

    var selectedDevice: AudioInputDevice? {
        guard let selectedDeviceID else { return nil }
        return rawDevices.first(where: { $0.id == selectedDeviceID })
    }

    var sourceSummary: AudioSourceSummary {
        AudioDeviceSelectionHelper.sourceSummary(
            deviceLabel: devices.first(where: { $0.id == selectedDeviceID })?.displayLabel,
            permission: permissionState,
            availableChannels: displayedChannels,
            selection: activeSelection
        )
    }

    /// Message shown under the source row on the Record tab. States already shown by the
    /// row itself (permission, no channels, no valid channel) are not repeated here.
    var recordTabMessage: AudioSourceUserMessage? {
        guard let userMessage, userMessage.isSourceChangeNotice else { return nil }
        return userMessage
    }

    var canSelectStereo: Bool {
        AudioDeviceSelectionHelper.allowsStereoSelection(availableChannels: displayedChannels)
    }

    func bindService() {
        service.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromService()
            }
            .store(in: &cancellables)

        service.$permissionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromService()
            }
            .store(in: &cancellables)
    }

    func makeMessage(kind: AudioSourceUserMessage.Kind, text: String, showsRetry: Bool) -> AudioSourceUserMessage {
        AudioSourceUserMessage(kind: kind, text: text, showsRetryPermissionAction: showsRetry)
    }

    func rememberValidSelection(_ selection: ChannelSelection, for deviceID: String) {
        switch selection.mode {
        case .mono:
            if let id = selection.monoChannelID { lastValidMonoByDevice[deviceID] = id }
        case .stereo:
            if let left = selection.stereoLeftChannelID, let right = selection.stereoRightChannelID {
                lastValidStereoByDevice[deviceID] = (left: left, right: right)
            }
        }
    }

    func activeMonoChannelID(for deviceID: String) -> String? {
        guard selectedDeviceID == deviceID, activeSelection?.mode == .mono else { return nil }
        return activeSelection?.monoChannelID
    }

    func activeStereoLeftID(for deviceID: String) -> String? {
        guard selectedDeviceID == deviceID, activeSelection?.mode == .stereo else { return nil }
        return activeSelection?.stereoLeftChannelID
    }

    func activeStereoRightID(for deviceID: String) -> String? {
        guard selectedDeviceID == deviceID, activeSelection?.mode == .stereo else { return nil }
        return activeSelection?.stereoRightChannelID
    }
}
