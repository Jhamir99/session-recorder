import Combine
import Foundation
import os
#if os(macOS)
import AppKit
#endif

/// The sessions folder in use, shared by every window (created once in `MyApp`; spec RF-1, RF-5).
/// Keeps security-scoped access to the chosen folder for the app's lifetime.
@MainActor
final class SessionsFolderStore: ObservableObject {
    @Published private(set) var folder: SessionsFolderInUse

    /// A folder change waiting for Move Sessions / Keep Them (RF-3).
    enum Target: Equatable {
        case app
        case chosen(URL)
    }
    @Published private(set) var pendingChange: Target?
    /// Sessions moved so far / total while moving.
    @Published private(set) var moveProgress: (done: Int, total: Int)?
    /// Shown after moving, e.g. "Moved 12 sessions."
    @Published var moveResult: String?
    /// Increases when the files in the folder change outside the library (after moving sessions).
    @Published private(set) var contentsVersion = 0

    private let repository: SessionsFolderRepository
    private let logger = Logger(subsystem: "SessionRecorder", category: "SessionsFolder")
    /// The chosen folder while its security-scoped access is open.
    private var accessedURL: URL?

    init(repository: SessionsFolderRepository? = nil) {
        let repository = repository ?? SessionsFolderRepository()
        self.repository = repository
        folder = .app(SessionsFolderService.appFolder)
        loadChosenFolder()
        #if os(macOS)
        // A drive can be plugged in or removed while the app is in front (RF-5).
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            volumeObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refreshAvailability() }
            })
        }
        #endif
    }

    #if os(macOS)
    nonisolated(unsafe) private var volumeObservers: [NSObjectProtocol] = []

    deinit {
        volumeObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
    #endif

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

    /// Number of sessions in the folder in use.
    private var sessionCountInCurrentFolder: Int {
        SessionsFolderService.sessionFiles(in: currentURL).count
    }

    /// Asks Move/Keep when sessions exist in the current folder; otherwise switches at once (RF-3).
    /// Throws when a picked folder cannot be used.
    func requestChange(to target: Target) throws {
        if case .chosen(let url) = target {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            guard SessionsFolderService.isAvailable(url) else { throw SessionsFolderService.FolderError.notAccessible }
            if url.standardizedFileURL == currentURL.standardizedFileURL { return }
        } else if folder == .app(SessionsFolderService.appFolder) {
            return
        }
        if moveResult != nil { moveResult = nil }
        if sessionCountInCurrentFolder > 0 {
            pendingChange = target
        } else {
            try apply(target)
        }
    }

    func cancelPendingChange() {
        // Called when the dialog closes (also after Move/Keep); only publish when something changes.
        guard pendingChange != nil else { return }
        pendingChange = nil
    }

    /// Switches to the pending folder; with `moveSessions`, moves the sessions from the previous folder (RF-3).
    func confirmPendingChange(moveSessions: Bool) {
        guard let target = pendingChange else { return }
        pendingChange = nil
        let source = currentURL
        // Keep access to the previous folder until its sessions have been moved.
        let previousAccess = accessedURL
        accessedURL = nil
        do {
            try apply(target, stopPreviousAccess: false)
        } catch {
            accessedURL = previousAccess
            moveResult = String(localized: "This folder can't be used. Choose another one.", comment: "Sessions folder: picked folder not accessible")
            return
        }
        guard moveSessions else {
            previousAccess?.stopAccessingSecurityScopedResource()
            return
        }
        let destination = currentURL
        moveProgress = (0, max(SessionsFolderService.sessionFiles(in: source).count, 1))
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                SessionsFolderService.moveSessions(from: source, to: destination) { done, total in
                    Task { @MainActor [weak self] in self?.moveProgress = (done, total) }
                }
            }.value
            previousAccess?.stopAccessingSecurityScopedResource()
            guard let self else { return }
            moveProgress = nil
            moveResult = SessionsFolderLogic.moveSummary(moved: result.moved, failed: result.failed)
            // Tell the library to list the moved files.
            contentsVersion += 1
        }
    }

    private func apply(_ target: Target, stopPreviousAccess: Bool = true) throws {
        switch target {
        case .app:
            useAppFolder(stopPreviousAccess: stopPreviousAccess)
        case .chosen(let url):
            try choose(url, stopPreviousAccess: stopPreviousAccess)
        }
    }

    /// Uses a folder picked by the user (URL from the system folder picker). Throws when it cannot be accessed.
    func choose(_ url: URL, stopPreviousAccess: Bool = true) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        guard SessionsFolderService.isAvailable(url) else {
            if didStart { url.stopAccessingSecurityScopedResource() }
            throw SessionsFolderService.FolderError.notAccessible
        }
        // A folder inside the app's own storage is the App Folder.
        if SessionsFolderLogic.isInsideAppStorage(url, appContainer: SessionsFolderService.appContainer) {
            if didStart { url.stopAccessingSecurityScopedResource() }
            useAppFolder(stopPreviousAccess: stopPreviousAccess)
            return
        }
        let bookmark = try SessionsFolderService.makeBookmark(for: url)
        if stopPreviousAccess { stopAccessingChosenFolder() }
        accessedURL = didStart ? url : nil
        repository.saveBookmark(bookmark)
        folder = .chosen(url)
    }

    func useAppFolder(stopPreviousAccess: Bool = true) {
        if stopPreviousAccess { stopAccessingChosenFolder() }
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
