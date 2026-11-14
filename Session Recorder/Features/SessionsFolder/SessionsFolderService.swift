import Foundation

/// Apple-API boundary for the chosen sessions folder (plan §2): access bookmarks, security-scoped access
/// and availability. Moving sessions is added with the move flow.
nonisolated enum SessionsFolderService {
    enum FolderError: Error {
        case notAccessible
    }

    /// The app's own `Documents/Sessions`.
    static var appFolder: URL { SessionFileStore.defaultSessionsDirectory }

    /// Root of the app's own storage (the sandbox container on Mac, the app's home on iOS).
    static var appContainer: URL { URL.homeDirectory }

    /// Bookmark that keeps access to a folder picked by the user. Mac needs a security-scoped bookmark
    /// (entitlement `com.apple.security.files.bookmarks.app-scope`); iOS keeps access with a plain one.
    static func makeBookmark(for url: URL) throws -> Data {
        #if os(macOS)
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        #endif
    }

    /// Folder URL from a saved bookmark; `isStale` means the bookmark should be created again.
    static func resolveBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        return (url, isStale)
    }

    /// The folder exists and can be read (drive connected, not deleted, access still granted).
    static func isAvailable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
            && isDirectory.boolValue
            && FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false))
    }

    // MARK: Moving sessions (RF-3)

    /// Session files (`.caf`) directly inside `folder`.
    static func sessionFiles(in folder: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls.filter { $0.pathExtension.lowercased() == SessionFileStore.fileExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Moves every session from `source` to `destination` one by one (coordinated, so iCloud Drive and other
    /// providers stay consistent), with unique names in the destination. A file that fails stays in `source`.
    /// Run off the main thread; `progress` gets (moved so far, total).
    static func moveSessions(from source: URL, to destination: URL, progress: (Int, Int) -> Void) -> (moved: Int, failed: Int) {
        let files = sessionFiles(in: source)
        guard !files.isEmpty else { return (0, 0) }
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var moved = 0
        var failed = 0
        for (index, file) in files.enumerated() {
            let existing = Set(((try? FileManager.default.contentsOfDirectory(atPath: destination.path(percentEncoded: false))) ?? []))
            let name = SessionsFolderLogic.uniqueFileName(
                name: file.deletingPathExtension().lastPathComponent,
                fileExtension: SessionFileStore.fileExtension,
                existingFileNames: existing
            )
            let target = destination.appending(path: name)
            if moveCoordinated(from: file, to: target) {
                moved += 1
            } else {
                failed += 1
            }
            progress(index + 1, files.count)
        }
        return (moved, failed)
    }

    private static func moveCoordinated(from source: URL, to target: URL) -> Bool {
        var coordinationError: NSError?
        var succeeded = false
        NSFileCoordinator().coordinate(
            writingItemAt: source, options: .forMoving,
            writingItemAt: target, options: .forReplacing,
            error: &coordinationError
        ) { sourceURL, targetURL in
            do {
                try FileManager.default.moveItem(at: sourceURL, to: targetURL)
                succeeded = true
            } catch {
                succeeded = false
            }
        }
        return coordinationError == nil && succeeded
    }

    /// Name shown in Settings, as the system shows it (e.g. "iCloud Drive" folders keep their visible name).
    static func displayName(of url: URL) -> String {
        FileManager.default.displayName(atPath: url.path(percentEncoded: false))
    }
}
