import AVFoundation
import Foundation
import os
#if os(macOS)
import AppKit
#endif

/// File operations on the Sessions folder (plan §3). Nonisolated and stateless, so it can run on
/// background tasks; reading audio headers never happens on the main thread (NFR-2).
nonisolated struct SessionLibraryStore: Sendable {
    let sessionsDirectory: URL

    init(sessionsDirectory: URL = SessionFileStore.defaultSessionsDirectory) {
        self.sessionsDirectory = sessionsDirectory
    }

    // MARK: List (RF-1)

    /// Every `.caf` file, newest first, with audio info still `.loading` (fast: no audio is read).
    /// Other files and folders are ignored. A missing folder means no sessions.
    func listSessions(calendar: Calendar = .current) -> [SessionItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey, .fileIdentifierKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        let items = urls
            .filter { $0.pathExtension.lowercased() == SessionFileStore.fileExtension }
            .compactMap { url -> SessionItem? in
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
                let name = url.deletingPathExtension().lastPathComponent
                return SessionItem(
                    url: url,
                    name: name,
                    recordedDate: SessionLibraryLogic.recordedDate(
                        creationDate: values.creationDate,
                        fileName: name,
                        modificationDate: values.contentModificationDate ?? .distantPast,
                        calendar: calendar
                    ),
                    fileSizeBytes: Int64(values.fileSize ?? 0),
                    audio: .loading,
                    fileID: values.fileIdentifier
                )
            }
        return SessionLibraryLogic.sorted(items)
    }

    /// Duration and format from the file header; `.unreadable` when the file is not usable audio.
    static func readAudioState(at url: URL) -> SessionItem.AudioState {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return .unreadable }
        let format = file.fileFormat
        let description = format.streamDescription.pointee
        let bitDepth = Int(description.mBitsPerChannel)
        return .readable(SessionAudioInfo(
            duration: Double(file.length) / format.sampleRate,
            format: SessionFormat(
                channelCount: Int(format.channelCount),
                sampleRate: format.sampleRate,
                bitDepth: bitDepth > 0 ? bitDepth : 16
            )
        ))
    }

    // MARK: Rename (RF-3)

    /// Renames the session file to `newName` (already validated) and returns the new URL.
    /// Moving keeps the creation (recorded) date, so the waveform cache still matches.
    func rename(_ url: URL, to newName: String) throws -> URL {
        let destination = sessionsDirectory.appending(path: newName).appendingPathExtension(SessionFileStore.fileExtension)
        guard destination.lastPathComponent != url.lastPathComponent else { return url }
        let fileManager = FileManager.default
        if destination.lastPathComponent.caseInsensitiveCompare(url.lastPathComponent) == .orderedSame {
            // Only the letter case changes: on a case-insensitive volume the target "exists" (it is the
            // same file), so move through a temporary name.
            let temporary = sessionsDirectory.appending(path: ".rename-\(UUID().uuidString)")
                .appendingPathExtension(SessionFileStore.fileExtension)
            try fileManager.moveItem(at: url, to: temporary)
            do {
                try fileManager.moveItem(at: temporary, to: destination)
            } catch {
                try? fileManager.moveItem(at: temporary, to: url)
                throw error
            }
        } else {
            try fileManager.moveItem(at: url, to: destination)
        }
        return destination
    }

    // MARK: Trim (RF-5)

    enum TrimError: Error, Equatable {
        case invalidRange
        case notEnoughStorage
        case cancelled
    }

    /// Copies `range` of the session into a new session named `newName` (already unique), with the same
    /// format (bit-exact: 16/24-bit PCM survives the Float32 round trip unchanged) and `recordedDate` as its
    /// creation date. Written to a temp file and moved into Sessions at the end, so a failure or
    /// cancellation leaves nothing behind (NFR-4). Run off the main thread.
    func trim(_ url: URL, range: TrimRange, newName: String, recordedDate: Date) throws -> URL {
        let source = try AVAudioFile(forReading: url)
        let frames = SessionLibraryLogic.frameRange(for: range, sampleRate: source.fileFormat.sampleRate, totalFrames: source.length)
        guard frames.count > 0 else { throw TrimError.invalidRange }

        let bytesPerFrame = Int64(source.fileFormat.streamDescription.pointee.mBytesPerFrame)
        let neededBytes = frames.count * max(bytesPerFrame, 1) + 1_000_000
        guard Self.freeBytes(at: sessionsDirectory) >= neededBytes else { throw TrimError.notEnoughStorage }

        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory.appending(path: "Trim", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let temporaryURL = temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension(SessionFileStore.fileExtension)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        do {
            // Scope the writer so the file is closed before it is moved.
            try {
                let output = try AVAudioFile(
                    forWriting: temporaryURL,
                    settings: source.fileFormat.settings,
                    commonFormat: source.processingFormat.commonFormat,
                    interleaved: source.processingFormat.isInterleaved
                )
                let chunkFrames = AVAudioFrameCount(max(source.processingFormat.sampleRate, 1))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: chunkFrames) else {
                    throw TrimError.invalidRange
                }
                source.framePosition = frames.start
                var remaining = frames.count
                while remaining > 0 {
                    if Task.isCancelled { throw TrimError.cancelled }
                    let toRead = AVAudioFrameCount(min(Int64(chunkFrames), remaining))
                    try source.read(into: buffer, frameCount: toRead)
                    guard buffer.frameLength > 0 else { break }
                    try output.write(from: buffer)
                    remaining -= Int64(buffer.frameLength)
                }
            }()
            try fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
            let destination = sessionsDirectory.appending(path: newName).appendingPathExtension(SessionFileStore.fileExtension)
            try fileManager.moveItem(at: temporaryURL, to: destination)
            try? fileManager.setAttributes([.creationDate: recordedDate], ofItemAtPath: destination.path)
            return destination
        }
    }

    /// Free bytes on the volume of `url` (same measure as recording).
    static func freeBytes(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
            return important
        }
        return Int64(values.volumeAvailableCapacity ?? 0)
    }

    // MARK: Delete (RF-4)

    /// Mac: moves the file to the Trash (restorable from Finder). iPhone/iPad: deletes it permanently
    /// (apps have no system Trash for their files). The waveform cache entry is removed too.
    func delete(_ url: URL, waveformService: WaveformService = WaveformService()) throws {
        // The cache key is read from the file, so remove the cache entry while the file still exists.
        waveformService.removeCache(for: url)
        #if os(macOS)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        // A chosen folder (iCloud Drive, other providers) may support "Recently Deleted"; the App Folder does not.
        if !SessionsFolderLogic.isInsideAppStorage(url, appContainer: SessionsFolderService.appContainer),
           (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil {
            return
        }
        try FileManager.default.removeItem(at: url)
        #endif
    }

    /// Wording for the delete confirmation, depending on where the file goes.
    static var deleteMovesToTrash: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    #if os(macOS)
    /// Opens a Finder window with the session file selected (RF-7).
    @MainActor
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif

    /// Names of all sessions (for rename and trim uniqueness).
    func existingNames() -> Set<String> {
        Set(listSessions().map(\.name))
    }
}
