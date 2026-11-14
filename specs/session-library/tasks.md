# Tasks: Session Library

Source: `specs/session-library/spec.md`, `specs/session-library/plan.md`.
Constraints: C1–C6 (SwiftUI/Apple APIs only, no deps, logic separated from UI, no personal data in persistence, English text). Keep tasks small (20–30 min), in dependency order (list → playback → rename/delete → trim → export). Paths are relative to `Session Recorder/`.

## Tasks

### Foundation
- [x] **T1 — Library models** (`Features/SessionLibrary/SessionLibraryModels.swift`)
  - **RF:** RF-1–RF-6
  - **Depends on:** none
  - **Done when:** Value types exist for session item, session format, export format + AAC bitrate, trim range, waveform data and library notices/errors; no I/O.

- [x] **T2 — Pure library logic** (`Features/SessionLibrary/SessionLibraryLogic.swift`)
  - **RF:** RF-1–RF-6
  - **Depends on:** T1
  - **Done when:** Pure functions cover sorting, recorded date (creation date / name / modification fallback), rename validation (empty, `/` `:`, duplicate case-insensitive), trimmed name + uniqueness, trim range (clamp, ≥ 1 s, frames, trimmed date), export size estimate, AAC rate, waveform bars and position ↔ x, cache key, and formatting; verified with a scratch script.

- [x] **T3 — Library store: list and info** (`Features/SessionLibrary/SessionLibraryStore.swift`, `Features/Recording/SessionFileStore.swift`)
  - **RF:** RF-1, NFR-2
  - **Depends on:** T1, T2
  - **Done when:** Lists `.caf` files in the shared Sessions directory with name, recorded date, size, and (off the main thread) duration/format; unreadable files are marked; non-CAF files ignored; checked with a scratch script on a temp folder.

### List (RF-1)
- [x] **T4 — Library view model + Sessions tab list** (`ViewModels/SessionLibraryViewModel.swift`, `Views/SessionLibraryView.swift`, `Views/SessionRow.swift`, `ContentView.swift`)
  - **RF:** RF-1, NFR-1
  - **Depends on:** T3
  - **Done when:** The Sessions tab shows sessions newest first (name, date, duration / "Can't be played"), the empty state when none, and the `REC` indicator; list + detail navigation adapts (stack on iPhone, split on iPad/Mac) with a placeholder detail.

- [x] **T5 — Keep the list in sync** (`RecordingViewModel.swift`, `SessionLibraryViewModel.swift`, `ContentView.swift`)
  - **RF:** RF-1
  - **Depends on:** T4
  - **Done when:** Saved and recovered recordings appear without leaving the tab; changes made in Files/Finder show when the app becomes active; an open detail of a removed session returns to the list.

- [x] **T6 — Files visibility (iOS) and Show in Finder (Mac)** (Info.plist keys — approved in plan §7; `SessionLibraryStore.swift`, row context menu)
  - **RF:** RF-7
  - **Depends on:** T4
  - **Done when:** On iPhone/iPad the Sessions folder is visible in Files ("On My iPhone › Session Recorder"); on Mac, Show in Finder reveals the file; the generated Info.plist contains the keys.

### Playback (RF-2)
- [x] **T7 — Waveform service + cache** (`Features/SessionLibrary/WaveformService.swift`)
  - **RF:** RF-2, NFR-2, NFR-3
  - **Depends on:** T2
  - **Done when:** Peaks (10/s) are computed in chunks off the main thread with partial results and cancel; saved to and read from `Caches/Waveforms/`; recomputed when missing or outdated; a 1 h file is checked with a scratch script (time, cache size).

- [x] **T8 — Detail view: info + waveform** (`ViewModels/SessionDetailViewModel.swift`, `Views/SessionDetailView.swift`, `Views/WaveformView.swift`)
  - **RF:** RF-2
  - **Depends on:** T4, T7
  - **Done when:** Selecting a session shows name, date, duration, format, size and the waveform filling progressively (loading state for long sessions).

- [x] **T9 — Player service + controls** (`Features/SessionLibrary/SessionPlayerService.swift`, `Views/PlayerControlsView.swift`, detail view model)
  - **RF:** RF-2
  - **Depends on:** T8
  - **Done when:** Play/pause, ±15 s, elapsed/total and seeking by tapping/dragging the waveform work; playback stops when leaving the detail or opening another session.

- [x] **T10 — Audio session hand-off with recording** (`AudioInputDeviceService.swift`, `RecordingViewModel.swift`, detail view model, `ContentView.swift`)
  - **RF:** RF-2
  - **Depends on:** T9
  - **Done when:** iOS plays through the speaker/route (not the receiver) in `.playback`; meters stop while playing and restart after; Record is unavailable while playing and selecting the Record tab stops playback; playback is disabled with an explanation while a recording exists.

- [x] **T11 — Background playback, Now Playing and interruptions** (`SessionPlayerService.swift`)
  - **RF:** RF-2
  - **Depends on:** T10
  - **Done when:** Playback continues with the device locked; lock screen / Control Center (and Mac Now Playing) show the session name and position with play/pause/skip; a call pauses playback without auto-resume.

### Rename and delete (RF-3, RF-4)
- [x] **T12 — Rename** (`SessionLibraryStore.swift`, `SessionLibraryViewModel.swift`, list + detail UI)
  - **RF:** RF-3
  - **Depends on:** T4, T8
  - **Done when:** Rename from list (swipe/context) and detail with inline validation (empty, `/` `:`, duplicate); the file is renamed, the date kept, the waveform cache still used.

- [ ] **T13 — Delete** (`SessionLibraryStore.swift`, `SessionLibraryViewModel.swift`, list + detail UI)
  - **RF:** RF-4
  - **Depends on:** T4, T9
  - **Done when:** Delete from list and detail with a confirmation naming the session; Mac moves to the Trash, iOS deletes permanently (text says so); playback stops first; the detail returns to the list; the cache entry is removed.

### Trim (RF-5)
- [ ] **T14 — Trim copy in the store** (`SessionLibraryStore.swift`)
  - **RF:** RF-5, NFR-4
  - **Depends on:** T3
  - **Done when:** A frame range is copied to a new CAF with identical settings via a temp file, named `<name> (trimmed)` (unique), with creation date = original + start; storage checked first; failure leaves no file; a scratch script confirms the samples match the original range.

- [ ] **T15 — Trim UI** (`ViewModels/SessionDetailViewModel+Trim.swift`, `Views/TrimControlsView.swift`, `WaveformView.swift`)
  - **RF:** RF-5
  - **Depends on:** T9, T14
  - **Done when:** Handles on the waveform with start/end/duration labels, Play Selection, Save disabled under 1 s; saving opens the new session and keeps the original.

### Share and export (RF-6)
- [ ] **T16 — Export service** (`Features/SessionLibrary/SessionExportService.swift`)
  - **RF:** RF-6, NFR-3, NFR-4
  - **Depends on:** T2
  - **Done when:** Original/WAV/AIFF/FLAC/ALAC/AAC (128–320 kbps) are written to `tmp/Export/<uuid>/` with progress and cancel; partial files removed on failure/cancel; leftover exports removed at launch; each format checked with `afinfo` in a scratch script.

- [ ] **T17 — Export sheet and sharing** (`ViewModels/SessionExportViewModel.swift`, `Views/ExportSheet.swift`, `SessionLibrarySettingsRepository.swift`)
  - **RF:** RF-6
  - **Depends on:** T8, T16
  - **Done when:** Share from detail and list context menu: format + bitrate, size estimate, Export with progress/Cancel, then Share… (system share sheet) and Save… on Mac; last format remembered (`library_export_format_v1`); temp files removed when the sheet closes.

### Mac and finishing
- [ ] **T18 — Session menu and keyboard shortcuts** (`Views/SessionLibraryCommands.swift`, `MyApp.swift`, `ContentView.swift`)
  - **RF:** RF-8
  - **Depends on:** T9, T12, T13
  - **Done when:** Play/Pause (Space), ⌘← / ⌘→, Rename…, Delete (⌘⌫), Show in Finder work on Mac (and iPad keyboard); Space never conflicts with the Recording menu or a rename text field.

- [ ] **T19 — Previews** (`ViewModels/SessionLibraryViewModel+Preview.swift`, `Views/SessionLibraryViews+Previews.swift`)
  - **RF:** C5
  - **Depends on:** T4–T17
  - **Done when:** Previews exist for list (empty / sessions / unreadable / recording), detail (loading / ready / playing / disabled), trim, export (choose / progress / ready / error), rename and delete dialogs; previews touch no files or audio.

- [ ] **T20 — Docs** (`AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2
  - **Depends on:** T19
  - **Done when:** Docs list `Features/SessionLibrary/` and the updated status.

- [ ] **T21 — Verification pass**
  - **RF:** RF-1–RF-8, NFR-1–NFR-6
  - **Depends on:** T1–T20
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; manual checks on a real iPhone and Mac cover every Completion Criterion in the spec, including a ≥ 1 h session and every export format opened in another app.
