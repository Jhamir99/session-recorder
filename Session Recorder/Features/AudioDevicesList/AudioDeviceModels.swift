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
