import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: String
    let displayName: String
    let channels: [AudioInputChannel]
}

struct AudioInputChannel: Identifiable, Equatable {
    let id: String
    let number: Int
    let name: String?
}

enum AudioChannelMode: String, Equatable, Codable {
    case mono
    case stereo
}

struct ChannelSelection: Equatable, Codable {
    var mode: AudioChannelMode
    var monoChannelID: String?
    var stereoLeftChannelID: String?
    var stereoRightChannelID: String?

    static func mono(channelID: String) -> ChannelSelection {
        ChannelSelection(
            mode: .mono,
            monoChannelID: channelID,
            stereoLeftChannelID: nil,
            stereoRightChannelID: nil
        )
    }

    static func stereo(leftChannelID: String, rightChannelID: String) -> ChannelSelection {
        ChannelSelection(
            mode: .stereo,
            monoChannelID: nil,
            stereoLeftChannelID: leftChannelID,
            stereoRightChannelID: rightChannelID
        )
    }
}

/// What the source row on the Record tab shows (RF-6).
enum AudioSourceSummary: Equatable {
    case noInputSelected
    case permissionRequired(deviceLabel: String)
    case noChannelsAvailable(deviceLabel: String)
    case noValidChannel(deviceLabel: String)
    /// Channel numbers in selection order: one for mono, left then right for stereo.
    case selected(deviceLabel: String, mode: AudioChannelMode, channelNumbers: [Int])
}

enum AudioInputPermissionState: Equatable {
    case unknown
    case granted
    case denied
    case restricted
}

struct AudioSourceUserMessage: Identifiable, Equatable {
    enum Kind: Equatable {
        case permissionRequired
        case noChannelsAvailable
        case noValidChannelAvailable
        case deviceDisconnected
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let showsRetryPermissionAction: Bool
}
