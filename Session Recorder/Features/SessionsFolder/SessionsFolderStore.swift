import Combine
import Foundation
import os

/// The sessions folder in use, shared by every window (created once in `MyApp`; spec RF-1, RF-5).
/// Keeps security-scoped access to the chosen folder for the app's lifetime.
@MainActor
final class SessionsFolderStore: ObservableObject {
    @Published private(set) var folder: SessionsFolderInUse

    private let repository: SessionsFolderRepository
    private let logger = Logger(subsystem: "SessionRecorder", category: "SessionsFolder")
    /// The chosen folder while its security-scoped access is open.
    private var accessedURL: URL?

    init(repository: SessionsFolderRepository? = nil) {
        let repository = repository ?? SessionsFolderRepository()
        self.repository = repository
        folder = .app(SessionsFolderService.appFolder)
        loadChosenFolder()
    }

    /// Where sessions are written and listed now (the App Folder while a chosen folder is unavailable).
    var currentURL: URL { folder.url }

    var isAppFolder: Bool { folder.isAppFolder }

    /// "App Folder" or the chosen folder's name (shown in Settings).
    var displayName: String {
        switch folder {
        case .app:
            String(localized: "App Folder", comment: "Sessions folder: the app's own folder")
        case .chosen(let url), .fallback(_, let url):
            SessionsFolderService.displayName(of: url)
        }
    }

    /// The chosen folder could not be accessed (RF-5).
    var isChosenFolderUnavailable: Bool {
        if case .fallback = folder { return true }
        return false
    }

    /// Uses a folder picked by the user (URL from the system folder picker). Throws when it cannot be accessed.
    func choose(_ url: URL) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        guard SessionsFolderService.isAvailable(url) else {
            if didStart { url.stopAccessingSecurityScopedResource() }
            throw SessionsFolderService.FolderError.notAccessible
        }
        // A folder inside the app's own storage is the App Folder.
        if SessionsFolderLogic.isInsideAppStorage(url, appContainer: SessionsFolderService.appContainer) {
            if didStart { url.stopAccessingSecurityScopedResource() }
            useAppFolder()
            return
        }
        let bookmark = try SessionsFolderService.makeBookmark(for: url)
        stopAccessingChosenFolder()
        accessedURL = didStart ? url : nil
        repository.saveBookmark(bookmark)
        folder = .chosen(url)
    }

    func useAppFolder() {
        stopAccessingChosenFolder()
        repository.clearBookmark()
        folder = .app(SessionsFolderService.appFolder)
    }

    /// Re-checks access (app became active, list refresh, recording stop): a drive may have been unplugged
    /// or plugged back in.
    func refreshAvailability() {
        guard repository.bookmark != nil else { return }
        loadChosenFolder()
    }

    private func loadChosenFolder() {
        guard let bookmark = repository.bookmark,
              let resolved = SessionsFolderService.resolveBookmark(bookmark) else {
            if repository.bookmark != nil {
                logger.error("Cannot resolve the sessions folder bookmark")
            }
            return
        }
        let url = resolved.url
        if accessedURL != url {
            stopAccessingChosenFolder()
            if url.startAccessingSecurityScopedResource() { accessedURL = url }
        }
        if resolved.isStale, let fresh = try? SessionsFolderService.makeBookmark(for: url) {
            repository.saveBookmark(fresh)
        }
        let available = SessionsFolderService.isAvailable(url)
        let newFolder = SessionsFolderLogic.folderInUse(
            appFolder: SessionsFolderService.appFolder,
            chosen: url,
            isChosenAvailable: available
        )
        if newFolder != folder { folder = newFolder }
    }

    private func stopAccessingChosenFolder() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }
}
