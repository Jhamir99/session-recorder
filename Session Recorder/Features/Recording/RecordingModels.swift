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
        // Decimal separator follows the user's region (44.1 kHz / 44,1 kHz; localization RF-4).
        let kilohertz = sampleRate / 1000
        return "\(kilohertz.formatted(.number.precision(.fractionLength(0...1)))) kHz"
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
        /// Sessions-folder RF-5: the chosen folder was unavailable, so the session went to the App Folder.
        case savedInAppFolder(sessionName: String)
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

    /// How the notice is shown: a failure, something that needs attention, or a saved session.
    enum Severity: Equatable {
        case error
        case warning
        case success
    }

    var severity: Severity {
        switch kind {
        case .startFailed, .storageFull, .recordingFailed:
            .error
        case .savedInAppFolder, .deviceDisconnected, .interrupted, .lowStorageWarning, .timeLimitReached(_, nil):
            .warning
        case .saved, .recovered, .timeLimitReached:
            .success
        }
    }

    /// Session this notice is about, when one was saved: the notice then offers View and Remove.
    var sessionName: String? {
        switch kind {
        case .saved(let name), .savedInAppFolder(let name), .recovered(let name), .storageFull(let name):
            name
        case .timeLimitReached(_, let name), .recordingFailed(let name):
            name
        case .startFailed, .deviceDisconnected, .interrupted, .lowStorageWarning:
            nil
        }
    }

    var text: String {
        switch kind {
        case .saved(let name):
            String(localized: "Saved: \(name)", comment: "Recording notice")
        case .savedInAppFolder(let name):
            String(localized: "The sessions folder isn't available, so the session was saved in the App Folder: \(name)", comment: "Recording notice")
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
