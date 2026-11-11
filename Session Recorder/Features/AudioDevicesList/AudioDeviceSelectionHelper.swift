import Foundation

enum AudioDeviceSelectionHelper {
    struct DisambiguatedDevice: Equatable, Identifiable {
        let id: String
        let displayLabel: String
    }

    enum ChannelAreaState: Equatable {
        case permissionRequired
        case noChannelsAvailable
        case channelList
    }

    enum SaveDecision: Equatable {
        case save(ChannelSelection)
        case none
    }

    struct RestoreResult: Equatable {
        let selection: ChannelSelection?

        static let noRestore = RestoreResult(selection: nil)
    }

    struct InvalidSelectionResult: Equatable {
        let shouldClearSelection: Bool
        let showsNoValidChannelError: Bool

        static let valid = InvalidSelectionResult(shouldClearSelection: false, showsNoValidChannelError: false)
        static let invalid = InvalidSelectionResult(shouldClearSelection: true, showsNoValidChannelError: true)
    }

    struct DisconnectResult: Equatable {
        let shouldClearSelection: Bool
        let showsDeviceDisconnectedError: Bool

        static let unchanged = DisconnectResult(shouldClearSelection: false, showsDeviceDisconnectedError: false)
        static let disconnected = DisconnectResult(shouldClearSelection: true, showsDeviceDisconnectedError: true)
    }

    static func disambiguateDeviceNames(_ devices: [AudioInputDevice]) -> [DisambiguatedDevice] {
        let totalByName = Dictionary(grouping: devices, by: \.displayName).mapValues(\.count)
        var indexByName: [String: Int] = [:]

        return devices.map { device in
            let label: String
            if totalByName[device.displayName, default: 0] > 1 {
                let nextIndex = (indexByName[device.displayName] ?? 0) + 1
                indexByName[device.displayName] = nextIndex
                label = "\(device.displayName) (\(nextIndex))"
            } else {
                label = device.displayName
            }
            return DisambiguatedDevice(id: device.id, displayLabel: label)
        }
    }

    static func formatChannelLabel(number: Int, optionalName: String?) -> String {
        guard let optionalName else { return "\(number)" }
        let trimmed = optionalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "\(number)" {
            return "\(number)"
        }
        return "\(number) (\(trimmed))"
    }

    static func channelAreaState(permission: AudioInputPermissionState, channels: [AudioInputChannel]) -> ChannelAreaState {
        guard permission == .granted else { return .permissionRequired }
        return channels.isEmpty ? .noChannelsAvailable : .channelList
    }

    static func initialMonoSelection(availableChannels: [AudioInputChannel]) -> ChannelSelection? {
        guard let first = availableChannels.first else { return nil }
        return .mono(channelID: first.id)
    }

    static func initialStereoSelection(availableChannels: [AudioInputChannel]) -> ChannelSelection? {
        guard availableChannels.count >= 2 else { return nil }
        return .stereo(leftChannelID: availableChannels[0].id, rightChannelID: availableChannels[1].id)
    }

    static func isMonoSelectionValid(channelID: String?, availableChannels: [AudioInputChannel]) -> Bool {
        guard let channelID else { return false }
        return availableChannels.contains(where: { $0.id == channelID })
    }

    static func isStereoSelectionValid(
        leftChannelID: String?,
        rightChannelID: String?,
        availableChannels: [AudioInputChannel]
    ) -> Bool {
        guard let leftChannelID, let rightChannelID else { return false }
        guard leftChannelID != rightChannelID else { return false }
        let availableIDs = Set(availableChannels.map(\.id))
        return availableIDs.contains(leftChannelID) && availableIDs.contains(rightChannelID)
    }

    static func allowsStereoSelection(availableChannels: [AudioInputChannel]) -> Bool {
        availableChannels.count >= 2
    }

    static func saveDecisionForMono(channelID: String, availableChannels: [AudioInputChannel]) -> SaveDecision {
        guard isMonoSelectionValid(channelID: channelID, availableChannels: availableChannels) else { return .none }
        return .save(.mono(channelID: channelID))
    }

    static func saveDecisionForStereo(
        leftChannelID: String?,
        rightChannelID: String?,
        availableChannels: [AudioInputChannel]
    ) -> SaveDecision {
        guard isStereoSelectionValid(
            leftChannelID: leftChannelID,
            rightChannelID: rightChannelID,
            availableChannels: availableChannels
        ), let leftChannelID, let rightChannelID else {
            return .none
        }
        return .save(.stereo(leftChannelID: leftChannelID, rightChannelID: rightChannelID))
    }

    static func replacementSelectionForTabSwitch(
        mode: AudioChannelMode,
        latestValidMonoChannelID: String?,
        latestValidStereoLeftChannelID: String?,
        latestValidStereoRightChannelID: String?,
        availableChannels: [AudioInputChannel]
    ) -> ChannelSelection? {
        switch mode {
        case .mono:
            guard let latestValidMonoChannelID,
                  isMonoSelectionValid(channelID: latestValidMonoChannelID, availableChannels: availableChannels) else {
                return nil
            }
            return .mono(channelID: latestValidMonoChannelID)
        case .stereo:
            guard isStereoSelectionValid(
                leftChannelID: latestValidStereoLeftChannelID,
                rightChannelID: latestValidStereoRightChannelID,
                availableChannels: availableChannels
            ), let latestValidStereoLeftChannelID, let latestValidStereoRightChannelID else {
                return nil
            }
            return .stereo(leftChannelID: latestValidStereoLeftChannelID, rightChannelID: latestValidStereoRightChannelID)
        }
    }

    static func restoreSelection(
        savedSelection: ChannelSelection?,
        isDeviceReliablyIdentified: Bool,
        availableChannels: [AudioInputChannel]
    ) -> RestoreResult {
        guard isDeviceReliablyIdentified, let savedSelection else { return .noRestore }

        switch savedSelection.mode {
        case .mono:
            guard isMonoSelectionValid(channelID: savedSelection.monoChannelID, availableChannels: availableChannels),
                  let channelID = savedSelection.monoChannelID else {
                return .noRestore
            }
            return RestoreResult(selection: .mono(channelID: channelID))
        case .stereo:
            guard isStereoSelectionValid(
                leftChannelID: savedSelection.stereoLeftChannelID,
                rightChannelID: savedSelection.stereoRightChannelID,
                availableChannels: availableChannels
            ), let leftID = savedSelection.stereoLeftChannelID,
               let rightID = savedSelection.stereoRightChannelID else {
                return .noRestore
            }
            return RestoreResult(selection: .stereo(leftChannelID: leftID, rightChannelID: rightID))
        }
    }

    static func invalidSelectionResult(
        selection: ChannelSelection?,
        availableChannels: [AudioInputChannel]
    ) -> InvalidSelectionResult {
        guard let selection else { return .valid }

        let isValid: Bool
        switch selection.mode {
        case .mono:
            isValid = isMonoSelectionValid(channelID: selection.monoChannelID, availableChannels: availableChannels)
        case .stereo:
            isValid = isStereoSelectionValid(
                leftChannelID: selection.stereoLeftChannelID,
                rightChannelID: selection.stereoRightChannelID,
                availableChannels: availableChannels
            )
        }
        return isValid ? .valid : .invalid
    }

    static func sourceSummary(
        deviceLabel: String?,
        permission: AudioInputPermissionState,
        availableChannels: [AudioInputChannel],
        selection: ChannelSelection?
    ) -> AudioSourceSummary {
        guard let deviceLabel else { return .noInputSelected }
        guard permission == .granted else { return .permissionRequired(deviceLabel: deviceLabel) }
        guard !availableChannels.isEmpty else { return .noChannelsAvailable(deviceLabel: deviceLabel) }

        let numberByID = Dictionary(uniqueKeysWithValues: availableChannels.map { ($0.id, $0.number) })
        let selectedIDs: [String?]
        switch selection?.mode {
        case .mono:
            selectedIDs = [selection?.monoChannelID]
        case .stereo:
            selectedIDs = [selection?.stereoLeftChannelID, selection?.stereoRightChannelID]
        case nil:
            return .noValidChannel(deviceLabel: deviceLabel)
        }

        let numbers = selectedIDs.compactMap { $0.flatMap { numberByID[$0] } }
        guard let selection, numbers.count == selectedIDs.count else {
            return .noValidChannel(deviceLabel: deviceLabel)
        }
        return .selected(deviceLabel: deviceLabel, mode: selection.mode, channelNumbers: numbers)
    }

    /// Mode and channels for the source row, e.g. "Mono · 1", "Stereo · 1–2", "Stereo · L 3 · R 1".
    static func sourceSummaryChannelText(mode: AudioChannelMode, channelNumbers: [Int]) -> String {
        switch mode {
        case .mono:
            return "Mono · " + channelNumbers.map(String.init).joined(separator: ", ")
        case .stereo:
            guard channelNumbers.count == 2 else { return "Stereo" }
            let left = channelNumbers[0], right = channelNumbers[1]
            // A range reads naturally only for an adjacent ascending pair.
            return right == left + 1 ? "Stereo · \(left)–\(right)" : "Stereo · L \(left) · R \(right)"
        }
    }

    // MARK: Automatic device selection (RF-7)
    // Each function returns the device ID to select, or nil to keep the current state.
    // "Built-in" means any non-external input (see `AudioInputDevice.isExternal`).

    /// At app start: last selected device if connected → first external → first built-in.
    static func launchSelection(devices: [AudioInputDevice], lastSelectedDeviceID: String?) -> String? {
        if let lastSelectedDeviceID, devices.contains(where: { $0.id == lastSelectedDeviceID }) {
            return lastSelectedDeviceID
        }
        return preferredDevice(in: devices)
    }

    /// When devices connect: switch to a newly connected external device only if the current
    /// source is built-in or nothing is selected. Never replaces another external device.
    static func selectionOnConnect(
        previousDeviceIDs: Set<String>,
        devices: [AudioInputDevice],
        selectedDeviceID: String?
    ) -> String? {
        if let selectedDeviceID,
           let selected = devices.first(where: { $0.id == selectedDeviceID }),
           selected.isExternal {
            return nil
        }
        return devices.first(where: { $0.isExternal && !previousDeviceIDs.contains($0.id) })?.id
    }

    /// When the selected device disconnects: first external → first built-in → nil (empty state).
    static func fallbackOnDisconnect(devices: [AudioInputDevice], disconnectedDeviceID: String) -> String? {
        preferredDevice(in: devices.filter { $0.id != disconnectedDeviceID })
    }

    /// When a device that was replaced by a fallback reconnects: select it again unless the
    /// user changed the source manually in the meantime.
    static func reselectionOnReconnect(
        replacedDeviceID: String?,
        userChangedSourceManually: Bool,
        devices: [AudioInputDevice]
    ) -> String? {
        guard let replacedDeviceID, !userChangedSourceManually,
              devices.contains(where: { $0.id == replacedDeviceID }) else {
            return nil
        }
        return replacedDeviceID
    }

    private static func preferredDevice(in devices: [AudioInputDevice]) -> String? {
        (devices.first(where: \.isExternal) ?? devices.first(where: { !$0.isExternal }))?.id
    }

    static func disconnectResult(selectedDeviceID: String?, availableDeviceIDs: Set<String>) -> DisconnectResult {
        guard let selectedDeviceID else { return .unchanged }
        return availableDeviceIDs.contains(selectedDeviceID) ? .unchanged : .disconnected
    }
}
