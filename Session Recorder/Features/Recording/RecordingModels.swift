import Foundation

/// Sample rate and bit depth of a recording (RF-1). Values only; no I/O.
struct RecordingQuality: Equatable, Hashable, Codable {
    var sampleRate: Double
    var bitDepth: Int

    /// For example `24-bit/48 kHz` or `16-bit/44.1 kHz`.
    var label: String {
        "\(bitDepth)-bit/\(Self.formatSampleRate(sampleRate))"
    }

    static func formatSampleRate(_ sampleRate: Double) -> String {
        let kilohertz = sampleRate / 1000
        let text = kilohertz.rounded() == kilohertz
            ? String(Int(kilohertz))
            : String(format: "%.1f", kilohertz)
        return "\(text) kHz"
    }
}

enum RecordingPauseReason: Equatable {
    case user
    case deviceDisconnected
    /// A call or another app took the audio input (iPhone/iPad).
    case interruption
}

enum RecordingState: Equatable {
    case idle
    case recording
    case paused(RecordingPauseReason)

    /// True while a recording file exists (recording or paused): the source is locked.
    var hasActiveRecording: Bool {
        self != .idle
    }
}

/// Live values shown while recording (RF-4).
struct RecordingLiveInfo: Equatable {
    var elapsedSeconds: TimeInterval
    var fileSizeBytes: Int64
    var remainingSeconds: TimeInterval

    static let zero = RecordingLiveInfo(elapsedSeconds: 0, fileSizeBytes: 0, remainingSeconds: 0)
}

/// Level of one recorded channel (RF-2).
struct ChannelLevel: Equatable {
    /// Peak level, linear 0...1 (1 = full scale).
    var peak: Float
    var isClipping: Bool

    static let silent = ChannelLevel(peak: 0, isClipping: false)
}

/// Why recording cannot start (RF-3).
enum RecordingStartError: Equatable {
    case permissionRequired
    case noValidSource
    case notEnoughStorage
    case deviceUnavailable
}

struct RecordingNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case saved(sessionName: String)
        case recovered(sessionName: String)
        case startFailed(RecordingStartError)
        case deviceDisconnected(deviceName: String)
        case interrupted
        case lowStorageWarning
        case storageFull(sessionName: String)
    }

    let id = UUID()
    let kind: Kind

    var isError: Bool {
        switch kind {
        case .saved, .recovered: false
        case .startFailed, .deviceDisconnected, .interrupted, .lowStorageWarning, .storageFull: true
        }
    }

    var text: String {
        switch kind {
        case .saved(let name):
            "Saved: \(name)"
        case .recovered(let name):
            "Recovered an interrupted recording: \(name)"
        case .startFailed(.permissionRequired):
            "Recording needs access to audio input."
        case .startFailed(.noValidSource):
            "Choose a device and channels before recording."
        case .startFailed(.notEnoughStorage):
            "Not enough free storage to record."
        case .startFailed(.deviceUnavailable):
            "The audio device is not available. Check the connection and try again."
        case .deviceDisconnected(let deviceName):
            "\(deviceName) disconnected. Recording paused."
        case .interrupted:
            "Recording paused by a call or another app."
        case .lowStorageWarning:
            "Storage is almost full: about 10 minutes of recording left."
        case .storageFull(let name):
            "Storage is full. Recording stopped and saved: \(name)"
        }
    }
}
