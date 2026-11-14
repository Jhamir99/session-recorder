import Foundation

/// Whether audio input can be used, from the user's point of view (spec RF-3).
enum AudioAccessState: Equatable {
    case allowed
    /// The system has not asked yet (the user chose Not Now, or nothing happened yet).
    case notAsked
    case denied
    /// Blocked by Screen Time or device management; the user cannot change it in the app's settings.
    case restricted
}

/// Button offered by the access notice (RF-3).
enum AudioAccessAction: Equatable {
    case allowAudioInput
    case openSettings
}

/// Pure first-use rules (plan §2): explicit inputs, no I/O.
enum AudioAccessLogic {
    static func accessState(for permission: AudioInputPermissionState) -> AudioAccessState {
        switch permission {
        case .granted: .allowed
        case .unknown: .notAsked
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    /// The explanation appears only before the first answer, and only once (RF-1, Decisions).
    static func showsExplanation(access: AudioAccessState, wasExplained: Bool) -> Bool {
        access == .notAsked && !wasExplained
    }

    static func noticeAction(for access: AudioAccessState) -> AudioAccessAction? {
        switch access {
        case .notAsked: .allowAudioInput
        case .denied: .openSettings
        case .restricted, .allowed: nil
        }
    }

    /// USB-C note: built-in input selected, no external device connected, no recording (RF-6).
    static func showsExternalDeviceNote(
        access: AudioAccessState,
        selectedDevice: AudioInputDevice?,
        devices: [AudioInputDevice],
        hasActiveRecording: Bool
    ) -> Bool {
        guard access == .allowed, !hasActiveRecording, let selectedDevice, !selectedDevice.isExternal else { return false }
        return !devices.contains(where: \.isExternal)
    }
}
