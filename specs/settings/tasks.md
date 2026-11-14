# Tasks: Settings

Source: `specs/settings/spec.md`, `specs/settings/plan.md`.
Constraints: C1–C6 (SwiftUI/Apple APIs only, no deps, logic separated from UI, no personal data in persistence, English text). Keep tasks small (20–30 min), in dependency order, grouped as approved (Settings screen + meters, recording, library, appearance). Paths are relative to `Session Recorder/`.

## Tasks

### Foundation and Settings screen
- [x] **T1 — Settings models and pure logic** (`Features/Settings/AppSettingsModels.swift`, `Features/Settings/SettingsLogic.swift`)
  - **RF:** RF-2–RF-14
  - **Depends on:** none
  - **Done when:** All options exist with the approved defaults; prefix validation, fade gain/length, time limit, warning threshold, held peak, segments, sort and storage summary are pure functions checked with a scratch script.

- [x] **T2 — Settings repository and shared store** (`Features/Settings/AppSettingsRepository.swift`, `Features/Settings/AppSettingsStore.swift`, `MyApp.swift`)
  - **RF:** RF-1, NFR-2
  - **Depends on:** T1
  - **Done when:** Settings load/save under `app_settings_v1` (bad data → defaults); one store is shared by all windows.

- [x] **T3 — Settings screen** (`Features/Settings/Views/SettingsView.swift`, `MyApp.swift`, `ContentView.swift`)
  - **RF:** RF-1
  - **Depends on:** T2
  - **Done when:** Mac: Settings… (⌘,) opens the window; iPhone/iPad: gear in Record and Sessions opens a sheet with Done; all options are shown in Recording / Library / Appearance and are remembered after a restart.

### Meters
- [x] **T4 — Segmented meter style** (`Features/Recording/Views/LevelMetersView.swift`)
  - **RF:** RF-2, NFR-3
  - **Depends on:** T3
  - **Done when:** Continuous/Segmented switch live; segments use the same scale and zones.

- [x] **T5 — Peak hold** (`RecordingModels.swift`, `RecordingViewModel.swift`, `LevelMetersView.swift`)
  - **RF:** RF-3
  - **Depends on:** T4
  - **Done when:** Off / 1 s / 3 s / Until reset behave as specified; tapping the meters resets Until reset.

### Recording options
- [x] **T6 — Fade at pause and resume** (`AudioCaptureService.swift`, `RecordingViewModel.swift`)
  - **RF:** RF-4, NFR-4
  - **Depends on:** T2
  - **Done when:** Short/Long fades remove the click; Off keeps today's behavior; disconnect/interruption pauses have no fade-out; a scratch check confirms samples outside the ramps are identical.

- [x] **T7 — Keep screen on (iPhone/iPad)** (`RecordingViewModel.swift`)
  - **RF:** RF-5
  - **Depends on:** T2
  - **Done when:** With the option on, the screen does not lock while a recording exists; normal after stop; not shown on Mac.

- [x] **T8 — Name prefix** (`RecordingLogic.swift`, `SessionFileStore.swift`, `RecordingViewModel.swift`)
  - **RF:** RF-7
  - **Depends on:** T2
  - **Done when:** New and recovered sessions use the prefix captured at start; invalid prefixes are refused with a message. (RF-6 "Quality for new devices" removed 2026-11-14.)

- [x] **T9 — Time limit and low-storage threshold** (`RecordingViewModel+Interruptions.swift`, `RecordingLogic.swift`, `RecordingModels.swift`)
  - **RF:** RF-8, RF-9
  - **Depends on:** T2
  - **Done when:** Reaching the limit stops, saves and shows the notice; the warning appears at the chosen threshold; the 1-minute stop is unchanged.

### Library
- [ ] **T10 — Default export format** (`SessionExportViewModel.swift`)
  - **RF:** RF-10
  - **Depends on:** T2
  - **Done when:** "Last used" keeps today's behavior; a fixed format is preselected in the share sheet.

- [ ] **T11 — Session order in the library** (`SessionLibraryLogic.swift`, `SessionLibraryViewModel.swift`, `SessionLibraryView.swift`, `AppSettingsRepository.swift`)
  - **RF:** RF-11
  - **Depends on:** T1
  - **Done when:** Toolbar sort menu with Newest First / Oldest First / Name (natural order), remembered under `library_sort_order_v1`.

- [ ] **T12 — Storage status line** (`SessionLibraryViewModel.swift`, `SessionLibraryView.swift`)
  - **RF:** RF-12
  - **Depends on:** T1
  - **Done when:** `N sessions · size · free available` at the bottom of the list on iPhone, iPad and Mac, updated with the list.

### Appearance
- [ ] **T13 — Theme** (`MyApp.swift`, `SettingsView.swift`)
  - **RF:** RF-13
  - **Depends on:** T3
  - **Done when:** System / Light / Dark apply immediately to all windows, sheets and the Mac Settings window.

- [ ] **T14 — Line waveform** (`WaveformView.swift`)
  - **RF:** RF-14
  - **Depends on:** T3
  - **Done when:** Bars / Line switch live in the detail and trim views.

### Finishing
- [ ] **T15 — Previews** (`Features/Settings/Views/SettingsViews+Previews.swift`)
  - **RF:** C5
  - **Depends on:** T3–T14
  - **Done when:** Previews for the settings form, segmented meter with peak hold, line waveform and storage line.

- [ ] **T16 — Docs** (`AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2
  - **Depends on:** T15
  - **Done when:** Docs list `Features/Settings/` and the updated status.

- [ ] **T17 — Verification pass**
  - **RF:** RF-1–RF-14, NFR-1–NFR-5
  - **Depends on:** T1–T16
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; every Completion Criterion in the spec verified on a real iPhone and Mac.
