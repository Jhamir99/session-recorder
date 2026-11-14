import Foundation

/// Sample rate and bit depth of a recording (RF-1). Values only; no I/O.
struct RecordingQuality: Equatable, Hashable, Codable {
    var sampleRate: Double
    var bitDepth: Int

    /// For example `24-bit/48 kHz` or `16-bit/44.1 kHz`.
    var label: String {
        "\(bitDepth)-bit/\(Self.formatSampleRate(sampleRate))"
    }

    nonisolated static func formatSampleRate(_ sampleRate: Double) -> String {
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
    /// Highest recent peak shown as a marker (settings RF-3); nil when peak hold is off.
    var heldPeak: Float? = nil

    static let silent = ChannelLevel(peak: 0, isClipping: false)
}

/// Why recording cannot start (RF-3).
enum RecordingStartError: Equatable {
    case permissionRequired
    case noValidSource
    case notEnoughStorage
    case deviceUnavailable
    case cannotCreateFile
}

struct RecordingNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case saved(sessionName: String)
        case recovered(sessionName: String)
        case startFailed(RecordingStartError)
        case deviceDisconnected(deviceName: String)
        case interrupted
        case lowStorageWarning(minutes: Int)
        /// Settings RF-8: stopped at the recording time limit.
        case timeLimitReached(limit: String, sessionName: String?)
        case storageFull(sessionName: String)
        /// Writing or capture failed; the recording was stopped and saved when it had audio.
        case recordingFailed(sessionName: String?)
    }

    let id = UUID()
    let kind: Kind

    var isError: Bool {
        switch kind {
        case .saved, .recovered: false
        case .startFailed, .deviceDisconnected, .interrupted, .lowStorageWarning, .storageFull, .recordingFailed: true
        case .timeLimitReached: false
        }
    }

    var text: String {
        switch kind {
        case .saved(let name):
            String(localized: "Saved: \(name)", comment: "Recording notice")
        case .recovered(let name):
            String(localized: "Recovered an interrupted recording: \(name)", comment: "Recording notice")
        case .startFailed(.permissionRequired):
            String(localized: "Recording needs access to audio input.", comment: "Recording notice")
        case .startFailed(.noValidSource):
            String(localized: "Choose a device and channels before recording.", comment: "Recording notice")
        case .startFailed(.notEnoughStorage):
            String(localized: "Not enough free storage to record.", comment: "Recording notice")
        case .startFailed(.deviceUnavailable):
            String(localized: "The audio device is not available. Check the connection and try again.", comment: "Recording notice")
        case .startFailed(.cannotCreateFile):
            String(localized: "The recording file could not be created.", comment: "Recording notice")
        case .deviceDisconnected(let deviceName):
            String(localized: "\(deviceName) disconnected. Recording paused.", comment: "Recording notice")
        case .interrupted:
            String(localized: "Recording paused by a call or another app.", comment: "Recording notice")
        case .lowStorageWarning(let minutes):
            String(localized: "Storage is almost full: about \(minutes) minutes of recording left.", comment: "Recording notice")
        case .timeLimitReached(let limit, let name?):
            String(localized: "Recording stopped after \(limit) (time limit). Saved: \(name)", comment: "Recording notice")
        case .timeLimitReached(let limit, nil):
            String(localized: "Recording stopped after \(limit) (time limit).", comment: "Recording notice")
        case .storageFull(let name):
            String(localized: "Storage is full. Recording stopped and saved: \(name)", comment: "Recording notice")
        case .recordingFailed(let name?):
            String(localized: "Recording stopped because of an audio error. Saved: \(name)", comment: "Recording notice")
        case .recordingFailed(nil):
            String(localized: "Recording stopped because of an audio error.", comment: "Recording notice")
        }
    }
}
