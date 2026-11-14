# Plan: Sessions Folder

## References
- `docs/constitution.md` (C1–C6)
- `specs/sessions-folder/spec.md` (RF-1–RF-6, NFR-1–NFR-5, Decisions)
- `specs/recording/plan.md` (in-progress file, recovery), `specs/session-library/plan.md` (store, delete, waveform cache), `specs/settings/plan.md` (settings screen and store)

## 1) Files to create or modify
New feature folder: `Session Recorder/Features/SessionsFolder/`.

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Features/SessionsFolder/SessionsFolderLogic.swift` | Create | **Pure logic**: which folder is in use (app / chosen / chosen-but-unavailable → app fallback), whether the warning shows (iOS + app folder), unique names when moving, "is this folder inside the app storage", move summary text. | RF-1–RF-3, RF-5 |
| `Features/SessionsFolder/SessionsFolderRepository.swift` | Create | `UserDefaults` key `sessions_folder_bookmark_v1`: the chosen folder's access bookmark (Mac: security-scoped). | RF-1, NFR-3 |
| `Features/SessionsFolder/SessionsFolderService.swift` | Create | Apple-API boundary: create/resolve the bookmark (refresh when stale), start/stop security-scoped access, check availability, move session files with progress (coordinated, off the main thread). | RF-1, RF-3–RF-5 |
| `Features/SessionsFolder/SessionsFolderStore.swift` | Create | Shared `ObservableObject` (created in `MyApp`): current folder URL, availability, display name; choose / use app folder; move flow state (asking, moving with progress, result). | RF-1, RF-3, RF-5 |
| `Features/SessionsFolder/Views/SessionsFolderSection.swift` | Create | Settings › Library rows: current folder, Choose Folder…, Use App Folder, App Folder warning (iOS), Move/Keep dialog, move progress and result. | RF-1–RF-3 |
| `Features/SessionsFolder/Views/FolderBrowserView.swift` | Create | iOS: system document browser (`UIDocumentPickerViewController` with `directoryURL`) shown in a sheet for **Show in Files**. | RF-6 |
| `Features/SessionsFolder/Views/SessionsFolderViews+Previews.swift` | Create | Previews: app folder with warning, chosen folder, unavailable, moving, move result. | C5 |
| `Features/Recording/SessionFileStore.swift` | Modify | Final sessions go to the folder in use (passed in when finishing/recovering); fallback to the app folder when unavailable (with a flag for the notice). In-progress files stay in Application Support. | RF-4, RF-5 |
| `Features/Recording/ViewModels/RecordingViewModel(+Interruptions).swift`, `RecordingModels.swift` | Modify | Use the folder store; notice "Saved in the App Folder because the sessions folder isn't available". | RF-4, RF-5 |
| `Features/SessionLibrary/SessionLibraryStore.swift`, `ViewModels/*`, `Views/SessionLibraryView.swift`, `Views/SessionDetailView.swift` | Modify | List/rename/delete/trim/share in the folder in use; unavailable notice with actions; iCloud placeholders listed and downloaded on demand; Show in Files (iOS). Delete text per location. | RF-4–RF-6 |
| `Features/Settings/Views/SettingsView.swift` | Modify | Embed `SessionsFolderSection` in the Library section. | RF-1 |
| `MyApp.swift`, `ContentView.swift` | Modify | Create and inject the folder store; refresh on app active. | RF-1, RF-5 |
| `Session Recorder/Session Recorder.entitlements` | Modify | Mac: `com.apple.security.files.bookmarks.app-scope` (security-scoped bookmarks to keep folder access after restart). | RF-1 |
| `Localizable.xcstrings` | Modify | Spanish for all new texts. | NFR-5 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md` | Modify | Feature folder, status. | C2 |

## 2) Technical design
### Folder access
- **Choose:** SwiftUI `fileImporter(allowedContentTypes: [.folder])` (iOS document picker / Mac open panel). The returned URL is security-scoped: `startAccessingSecurityScopedResource()`, then a bookmark is saved (Mac: `.withSecurityScope`; iOS: minimal bookmark, which keeps access for picked folders).
- **Launch:** resolve the bookmark; if stale, recreate it; start access and keep it for the app's lifetime (stop when switching folders).
- **Availability:** folder exists and is readable; checked when the app becomes active, when listing and when a recording stops.
- **In app storage?** A picked folder inside the app container is treated as the App Folder.

### Where things are written
```text
recording in progress   → Application Support/InProgress (unchanged, always private)
stop / recover          → folder in use; if unavailable → App Folder + notice (nothing lost)
library operations      → folder in use (list, rename, delete, trim, share)
waveform cache          → Caches (unchanged; keys do not depend on the folder)
```

### Moving sessions
- Asked after choosing a folder when the current folder has sessions: **Move Sessions** / **Keep Them**.
- Files moved one by one off the main thread with `NSFileCoordinator` (iCloud/provider safe); progress = files moved / total (plus bytes for large files); unique names in the destination; result "Moved N sessions" or "N sessions could not be moved".
- Recording to the folder waits for the move to finish (the stopped recording is queued, or saved to the App Folder if the user stops during a move).

### iCloud Drive placeholders
- Files not downloaded appear as `.<name>.caf.icloud`: listed as sessions that are downloading; `startDownloadingUbiquitousItem` is requested when the list loads; they become playable when downloaded (refresh on app active / list refresh).

### Show in Files (iOS)
- Sheet with `UIDocumentPickerViewController(forOpeningContentTypes: [.item])`, `directoryURL` = the session's folder; the user browses like in Files (picking a file just closes the sheet).

## 3) Decisions approved before implementation (2026-11-14)
1. **New files** in `Features/SessionsFolder/` listed in §1.
2. **UserDefaults key** `sessions_folder_bookmark_v1` (the folder access bookmark).
3. **Mac entitlement** `com.apple.security.files.bookmarks.app-scope` (needed so the Mac remembers access to the chosen folder after restarting).

## 4) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Pure logic | Scratch script for `SessionsFolderLogic`. | RF-1–RF-3, RF-5 |
| Move | Scratch script with temp folders: move with name clashes, failure part-way, nothing lost or duplicated. | RF-3, NFR-2 |
| Build | `xcodebuild` macOS + iOS Simulator; catalog synced, 0 untranslated. | NFR-1, NFR-5 |
| Real devices | iPhone: choose "On My iPhone" folder, iCloud Drive, USB drive; move/keep; record; unplug the drive (notice + fallback); delete and reinstall the app (sessions survive, choose folder again); Show in Files. Mac: choose a folder, restart (access kept), Show in Finder. | RF-1–RF-6 |
