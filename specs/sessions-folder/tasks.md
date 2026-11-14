# Tasks: Sessions Folder

Source: `specs/sessions-folder/spec.md`, `specs/sessions-folder/plan.md`.
Constraints: C1–C6 (Apple APIs only, no deps, logic separated from UI, no audio ever lost, English + Spanish text). Keep tasks small, in dependency order. Paths are relative to `Session Recorder/`.

## Tasks

- [x] **T1 — Folder logic and bookmark storage** (`Features/SessionsFolder/SessionsFolderLogic.swift`, `SessionsFolderRepository.swift`)
  - **RF:** RF-1–RF-3, RF-5, NFR-3
  - **Depends on:** none
  - **Done when:** Pure rules (folder in use, warning, inside-app check, unique names, move summary) checked with a scratch script; the bookmark can be saved and loaded.

- [x] **T2 — Folder service and shared store** (`SessionsFolderService.swift`, `SessionsFolderStore.swift`, `MyApp.swift`, entitlements)
  - **RF:** RF-1, RF-5
  - **Depends on:** T1
  - **Done when:** A chosen folder is resolved at launch with access (Mac and iOS), availability is tracked (app active), App Folder fallback works.

- [x] **T3 — Settings: choose folder and warning** (`Views/SessionsFolderSection.swift`, `SettingsView.swift`)
  - **RF:** RF-1, RF-2
  - **Depends on:** T2
  - **Done when:** Current folder shown; Choose Folder… / Use App Folder work and are remembered after restart; warning on iPhone/iPad only with the App Folder.

- [x] **T4 — Library and recording use the folder** (`SessionFileStore.swift`, `RecordingViewModel*`, `SessionLibraryStore.swift`, library view models)
  - **RF:** RF-4
  - **Depends on:** T2
  - **Done when:** New/recovered sessions are saved in the chosen folder; list, play, rename, delete (text per location), trim and share work there.

- [x] **T5 — Moving sessions** (`SessionsFolderService.swift`, `SessionsFolderStore.swift`, `SessionsFolderSection.swift`)
  - **RF:** RF-3, NFR-2, NFR-4
  - **Depends on:** T3, T4
  - **Done when:** Move/Keep dialog; move with progress and unique names; partial failure reported; scratch script confirms nothing is lost or duplicated.

- [x] **T6 — Folder not available** (`SessionsFolderStore.swift`, `SessionLibraryView.swift`, recording notice)
  - **RF:** RF-5, NFR-2
  - **Depends on:** T4
  - **Done when:** Library notice with actions; a recording stopped meanwhile is saved in the App Folder with a notice; sessions reappear when the folder is back.

- [x] **T7 — iCloud Drive placeholders** (`SessionLibraryStore.swift`, `SessionLibraryViewModel.swift`, `SessionRow.swift`)
  - **RF:** RF-4
  - **Depends on:** T4
  - **Done when:** Not-downloaded sessions are listed as downloading, are downloaded on demand and become playable.

- [x] **T8 — Show in Files (iOS)** (`Views/FolderBrowserView.swift`, `SessionDetailView.swift`)
  - **RF:** RF-6
  - **Depends on:** T4
  - **Done when:** The detail menu opens the system file browser at the session's folder on iPhone/iPad; Mac keeps Show in Finder.

- [ ] **T9 — Spanish texts and previews** (`Localizable.xcstrings`, `Views/SessionsFolderViews+Previews.swift`)
  - **RF:** NFR-5, C5
  - **Depends on:** T3–T8
  - **Done when:** Catalog synced with 0 untranslated strings; previews for app folder + warning, chosen folder, unavailable, moving, move result.

- [ ] **T10 — Docs** (`AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2
  - **Depends on:** T9
  - **Done when:** Docs list `Features/SessionsFolder/` and the updated status.

- [ ] **T11 — Verification pass**
  - **RF:** RF-1–RF-6, NFR-1–NFR-5
  - **Depends on:** T1–T10
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; every Completion Criterion verified on a real iPhone and Mac, including delete + reinstall on iPhone with sessions in a chosen folder.
