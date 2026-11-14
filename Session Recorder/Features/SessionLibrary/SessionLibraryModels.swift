import Foundation

/// Audio format of a session file, e.g. `Stereo · 24-bit/48 kHz` (RF-2).
nonisolated struct SessionFormat: Equatable, Hashable {
    var channelCount: Int
    var sampleRate: Double
    var bitDepth: Int

    var label: String {
        let channels = switch channelCount {
        case 1: String(localized: "Mono", comment: "Channel mode")
        case 2: String(localized: "Stereo", comment: "Channel mode")
        default: String(localized: "\(channelCount) ch", comment: "Number of channels, short")
        }
        return "\(channels) · \(bitDepth)-bit/\(RecordingQuality.formatSampleRate(sampleRate))"
    }

    /// Uncompressed PCM bytes per second.
    var bytesPerSecond: Double {
        sampleRate * Double(bitDepth / 8) * Double(channelCount)
    }
}

/// Audio details read from the file header; nil when the file cannot be read.
nonisolated struct SessionAudioInfo: Equatable, Hashable {
    var duration: TimeInterval
    var format: SessionFormat
}

/// One session in the library: a `.caf` file in the Sessions folder (RF-1).
nonisolated struct SessionItem: Identifiable, Equatable, Hashable {
    /// The file URL; the session name is the file name, so it changes on rename.
    var url: URL
    var name: String
    var recordedDate: Date
    var fileSizeBytes: Int64
    /// Filled asynchronously (`.loading` first) so the list appears immediately (NFR-2).
    var audio: AudioState
    /// File system identifier: kept when the file is renamed, so the selection and an open detail
    /// (with its playback) survive a rename (RF-3).
    var fileID: UInt64? = nil

    enum AudioState: Equatable, Hashable {
        case loading
        case readable(SessionAudioInfo)
        /// The file is damaged or not audio: listed as "Can't be played" (RF-1).
        case unreadable
        /// In iCloud Drive (or another provider) and not on this device yet; being downloaded
        /// (sessions-folder RF-4).
        case downloading
    }

    /// Stable across renames when the file system provides an identifier; otherwise the path.
    var id: String { fileID.map { "file-\($0)" } ?? url.path }

    var audioInfo: SessionAudioInfo? {
        if case .readable(let info) = audio { return info }
        return nil
    }

    var isUnreadable: Bool {
        audio == .unreadable
    }

    /// Not downloaded yet: cannot be played, trimmed or shared until it is.
    var isDownloading: Bool {
        audio == .downloading
    }
}

/// Export formats offered when sharing (RF-6).
nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case original
    case wav
    case aiff
    case flac
    case alac
    case aac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original: String(localized: "Original (CAF)", comment: "Export format: the session file as it is")
        case .wav: "WAV"
        case .aiff: "AIFF"
        case .flac: "FLAC"
        case .alac: "Apple Lossless (ALAC)"
        case .aac: "AAC (M4A)"
        }
    }

    var fileExtension: String {
        switch self {
        case .original: "caf"
        case .wav: "wav"
        case .aiff: "aiff"
        case .flac: "flac"
        case .alac, .aac: "m4a"
        }
    }

    var isLossless: Bool {
        self != .aac
    }
}

/// AAC bitrates offered when exporting (RF-6). 320 kbps was removed (2026-11-14): the encoder failed with it.
nonisolated enum AACBitrate: Int, CaseIterable, Identifiable, Codable {
    case kbps128 = 128
    case kbps192 = 192
    case kbps256 = 256

    var id: Int { rawValue }
    var bitsPerSecond: Int { rawValue * 1000 }
    var title: String { "\(rawValue) kbps" }
}

/// Export format and bitrate remembered between shares (RF-6).
nonisolated struct ExportChoice: Equatable, Codable {
    var format: ExportFormat
    var aacBitrate: AACBitrate

    static let `default` = ExportChoice(format: .original, aacBitrate: .kbps256)
}

/// How a session detail asks the app to switch between playback and recording audio (plan §3).
/// `begin` gets a closure that stops this playback (e.g. when the Record tab is selected).
struct PlaybackHandoff {
    var begin: (_ stop: @escaping @MainActor () -> Void) async -> Void
    var end: () async -> Void

    /// Previews and checks: nothing to switch.
    static let none = PlaybackHandoff(begin: { _ in }, end: {})
}

/// What a session detail needs from the library to save a trimmed copy (RF-5).
struct TrimContext {
    /// Names of all sessions, for a unique `(trimmed)` name.
    var existingNames: () -> Set<String>
    /// Folder the trimmed session is saved in (the sessions folder in use).
    var sessionsDirectory: () -> URL
    /// Called with the new file so the library lists and opens it.
    var didSave: (URL) -> Void

    static let none = TrimContext(existingNames: { [] }, sessionsDirectory: { SessionFileStore.defaultSessionsDirectory }, didSave: { _ in })
}

/// Selected part of a session for trimming, in seconds from the start (RF-5).
nonisolated struct TrimRange: Equatable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval { end - start }
}

/// Waveform overview: one peak per `1 / peaksPerSecond` seconds, 0...1 (max of all channels) (RF-2).
nonisolated struct WaveformData: Equatable {
    static let defaultPeaksPerSecond = 10

    var peaksPerSecond: Int
    var peaks: [Float]

    var duration: TimeInterval {
        Double(peaks.count) / Double(peaksPerSecond)
    }
}

/// Why a rename was refused (RF-3).
nonisolated enum RenameError: Error, Equatable {
    case empty
    case invalidCharacters
    case duplicate

    var message: String {
        switch self {
        case .empty: String(localized: "Enter a name.", comment: "Session library text")
        case .invalidCharacters: String(localized: "Names can't contain “/” or “:”.", comment: "Session library text")
        case .duplicate: String(localized: "Another session already has this name.", comment: "Session library text")
        }
    }
}

/// Short messages shown in the library after an operation (RF-3–RF-6).
struct LibraryNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case trimmed(sessionName: String)
        case notEnoughStorage
        /// The whole localized message, e.g. "Renaming failed. Please try again."
        case operationFailed(message: String)
    }

    let id = UUID()
    let kind: Kind

    var isError: Bool {
        if case .trimmed = kind { return false }
        return true
    }

    var text: String {
        switch kind {
        case .trimmed(let name): String(localized: "Saved: \(name)", comment: "Notice after saving a trimmed session")
        case .notEnoughStorage: String(localized: "Not enough free storage.", comment: "Session library text")
        case .operationFailed(let message): message
        }
    }
}
