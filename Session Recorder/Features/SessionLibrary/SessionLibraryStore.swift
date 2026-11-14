import AVFoundation
import Foundation
import os

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
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]
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
                    audio: .loading
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

    /// Names of all sessions (for rename and trim uniqueness).
    func existingNames() -> Set<String> {
        Set(listSessions().map(\.name))
    }
}
