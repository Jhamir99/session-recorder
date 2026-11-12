import AVFoundation
import Foundation
import os

/// Session files on disk (plan §4; storage decision approved 2026-11-12):
/// - `Documents/Sessions/<session name>.caf`: saved sessions (later visible in Files/Finder).
/// - `Application Support/InProgress/<start date>.caf`: the recording in progress; moved to Sessions on stop.
///   The start date in its name lets an interrupted recording be recovered without extra persisted state.
final class SessionFileStore {
    static let fileExtension = "caf"

    let sessionsDirectory: URL
    let inProgressDirectory: URL
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "SessionRecorder", category: "SessionFiles")

    /// Directories can be injected for checks outside the app.
    init(sessionsDirectory: URL? = nil, inProgressDirectory: URL? = nil) {
        self.sessionsDirectory = sessionsDirectory
            ?? URL.documentsDirectory.appending(path: "Sessions", directoryHint: .isDirectory)
        self.inProgressDirectory = inProgressDirectory
            ?? URL.applicationSupportDirectory.appending(path: "InProgress", directoryHint: .isDirectory)
    }

    // MARK: Recording (RF-3)

    /// Creates the in-progress CAF file (linear PCM at `quality`) and returns its writer.
    func createRecording(startDate: Date, quality: RecordingQuality, channelCount: Int) throws -> RecordingFileWriter {
        try fileManager.createDirectory(at: inProgressDirectory, withIntermediateDirectories: true)
        let url = inProgressDirectory
            .appending(path: Self.inProgressFileName(for: startDate))
            .appendingPathExtension(Self.fileExtension)
        return try RecordingFileWriter(url: url, quality: quality, channelCount: channelCount)
    }

    /// Moves a finished recording to Sessions with a unique date-based name (RF-6).
    /// Returns nil and deletes the file when it contains no audio.
    func finishRecording(at url: URL, startDate: Date, hasAudio: Bool) throws -> String? {
        guard hasAudio else {
            try? fileManager.removeItem(at: url)
            return nil
        }
        try fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        let name = RecordingLogic.sessionName(
            startDate: startDate,
            calendar: .current,
            existingNames: existingSessionNames()
        )
        let destination = sessionsDirectory.appending(path: name).appendingPathExtension(Self.fileExtension)
        try fileManager.moveItem(at: url, to: destination)
        return name
    }

    // MARK: Recovery (RF-8, NFR-4)

    /// Saves recordings left in progress by a terminated app as sessions; deletes empty ones.
    /// Call at launch, before any new recording starts. Returns the recovered session names.
    func recoverInterruptedRecordings() -> [String] {
        let urls = (try? fileManager.contentsOfDirectory(at: inProgressDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                let startDate = Self.startDate(fromInProgressFileName: url.deletingPathExtension().lastPathComponent)
                    ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
                    ?? Date()
                do {
                    return try finishRecording(at: url, startDate: startDate, hasAudio: Self.hasAudio(at: url))
                } catch {
                    logger.error("Cannot recover \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
    }

    /// A file that cannot be opened is kept (treated as audio) so nothing recorded is ever deleted.
    private static func hasAudio(at url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return true }
        return file.length > 0
    }

    // MARK: Storage (RF-4, RF-8)

    /// Free bytes on the volume that holds the sessions.
    func freeBytes() -> Int64 {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? URL.documentsDirectory.resourceValues(forKeys: keys) else { return 0 }
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return important
        }
        return Int64(values.volumeAvailableCapacity ?? 0)
    }

    // MARK: Names

    private func existingSessionNames() -> Set<String> {
        let urls = (try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)) ?? []
        return Set(urls.map { $0.deletingPathExtension().lastPathComponent })
    }

    /// Local time with seconds, e.g. `2026-11-11T22-30-05` (no `:` in file names).
    private static func makeInProgressFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return formatter
    }

    static func inProgressFileName(for startDate: Date) -> String {
        makeInProgressFormatter().string(from: startDate)
    }

    static func startDate(fromInProgressFileName name: String) -> Date? {
        makeInProgressFormatter().date(from: name)
    }
}

/// Writes Float32 non-interleaved buffers to a CAF file as linear PCM at the recording quality.
/// Used from the capture queue (not the main actor); counters can be read from any thread.
nonisolated final class RecordingFileWriter: @unchecked Sendable {
    let url: URL
    let quality: RecordingQuality
    let channelCount: Int
    /// Format of the buffers passed to `write` (the file converts them to integer PCM).
    let processingFormat: AVAudioFormat

    private let file: AVAudioFile
    private let lock = NSLock()
    private var writtenFrames: AVAudioFramePosition = 0

    init(url: URL, quality: RecordingQuality, channelCount: Int) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: quality.sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: quality.bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        self.url = url
        self.quality = quality
        self.channelCount = channelCount
        processingFormat = file.processingFormat
    }

    /// `buffer` must match `processingFormat` (Float32 non-interleaved, recording rate and channel count).
    func write(_ buffer: AVAudioPCMBuffer) throws {
        try file.write(from: buffer)
        lock.withLock { writtenFrames += AVAudioFramePosition(buffer.frameLength) }
    }

    var framesWritten: AVAudioFramePosition {
        lock.withLock { writtenFrames }
    }

    /// Recorded time; paused time is never written, so it is excluded (RF-4).
    var elapsedSeconds: TimeInterval {
        Double(framesWritten) / quality.sampleRate
    }

    /// Audio data size (header excluded, a few KB).
    var fileSizeBytes: Int64 {
        Int64(framesWritten) * Int64(quality.bitDepth / 8) * Int64(channelCount)
    }

    /// Flushes and closes the file; call before moving it.
    func close() {
        file.close()
    }
}
