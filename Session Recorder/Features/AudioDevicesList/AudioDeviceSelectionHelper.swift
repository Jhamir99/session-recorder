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

    static func disconnectResult(selectedDeviceID: String?, availableDeviceIDs: Set<String>) -> DisconnectResult {
        guard let selectedDeviceID else { return .unchanged }
        return availableDeviceIDs.contains(selectedDeviceID) ? .unchanged : .disconnected
    }
}
