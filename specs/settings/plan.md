# Plan: Settings

## References
- `docs/constitution.md` (C1–C6)
- `specs/settings/spec.md` (RF-1–RF-14, NFR-1–NFR-5, Decisions)
- `specs/recording/spec.md` (RF-1 quality, RF-2 meters, RF-5 pause, RF-6 naming, RF-7 background, RF-8 storage)
- `specs/session-library/spec.md` (RF-1 list, RF-2 waveform, RF-3 rename rules, RF-6 export)

## 1) Files to create or modify (responsibility + RF coverage)
New feature folder: `Session Recorder/Features/Settings/`.

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Features/Settings/AppSettingsModels.swift` | Create | Value types: `MeterStyle`, `PeakHold`, `PauseFade` (off/short/long + duration), `DefaultQualityRule`, `RecordingTimeLimit`, `LowStorageWarning`, `ExportDefault` (last used / fixed `ExportChoice`), `AppTheme`, `WaveformStyle`, and `AppSettings` (all values with defaults, `Codable`). `SessionSortOrder` for the library. | RF-2–RF-11, RF-13, RF-14 |
| `Features/Settings/SettingsLogic.swift` | Create | **Pure logic**: prefix validation (reuses rename rules + 30 characters), fade gain for a frame (linear ramp), time-limit reached, warning threshold seconds, peak-hold value over time, segment levels for the segmented meter, "highest available" quality. | RF-3, RF-4, RF-6–RF-9, RF-2 |
| `Features/Settings/AppSettingsRepository.swift` | Create | `UserDefaults`: `app_settings_v1` (JSON of `AppSettings`) and `library_sort_order_v1`. Unknown/invalid data → defaults. | RF-1, RF-11, NFR-2 |
| `Features/Settings/AppSettingsStore.swift` | Create | Shared `ObservableObject` with the current settings; saves on every change; one instance per app (shared by all windows and the Mac Settings window). | RF-1 |
| `Features/Settings/Views/SettingsView.swift` | Create | Form with Recording / Library / Appearance sections (pickers, toggle, prefix field with validation); Mac Settings window and iOS sheet (Done). | RF-1–RF-10, RF-13, RF-14 |
| `Features/Settings/Views/SettingsViews+Previews.swift` | Create | Previews: settings form (iPhone/Mac sizes), segmented meter, peak hold, line waveform, storage line. | C5 |
| `MyApp.swift` | Modify | Own `AppSettingsStore`; `Settings { SettingsView() }` scene on Mac; inject the store; apply the theme (`preferredColorScheme`). | RF-1, RF-13 |
| `ContentView.swift` | Modify | Gear button in the Record and Sessions toolbars (iPhone/iPad) → settings sheet; pass settings to the recording and library view models. | RF-1 |
| `Features/Recording/Views/LevelMetersView.swift` | Modify | Segmented style; peak-hold marker; tap/click to reset (Until reset). | RF-2, RF-3 |
| `Features/Recording/RecordingModels.swift` | Modify | `ChannelLevel` gains the held peak. | RF-3 |
| `Features/Recording/RecordingLogic.swift` | Modify | `sessionName` takes the prefix; `storageDecision` takes the warning threshold; default quality takes the rule. | RF-6, RF-7, RF-9 |
| `Features/Recording/ViewModels/RecordingViewModel.swift` (+ `+Interruptions`) | Modify | Use settings: held peaks, prefix/quality captured at start, time limit (stop + notice), warning threshold, keep screen on (`isIdleTimerDisabled` on iOS while a recording exists), fade length passed to capture. | RF-3, RF-5–RF-9 |
| `Features/Recording/RecordingModels.swift` | Modify | Notice `timeLimitReached(limit:, sessionName:)`. | RF-8 |
| `Features/Recording/SessionFileStore.swift` | Modify | Finish/recover with the prefix. | RF-7 |
| `Features/Recording/AudioCaptureService.swift` | Modify | `CaptureSampleProcessor`: fade-out over N frames before writing stops (pause), fade-in over N frames after resume; no fade for disconnect/interruption pauses; gain applied only inside the ramps (bit-exact elsewhere). | RF-4, NFR-4 |
| `Features/SessionLibrary/SessionLibraryLogic.swift` | Modify | Sort by order (newest, oldest, name with natural comparison); storage summary text. | RF-11, RF-12 |
| `Features/SessionLibrary/ViewModels/SessionLibraryViewModel.swift` | Modify | Sort order (saved), storage summary (session count, total bytes, free bytes) refreshed with the list. | RF-11, RF-12 |
| `Features/SessionLibrary/Views/SessionLibraryView.swift` | Modify | Sort menu and gear in the toolbar; storage line at the bottom of the list. | RF-1, RF-11, RF-12 |
| `Features/SessionLibrary/ViewModels/SessionExportViewModel.swift` | Modify | Initial choice from the export default (fixed format) or last used. | RF-10 |
| `Features/SessionLibrary/Views/WaveformView.swift` | Modify | Line style (filled outline). | RF-14 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `Session Recorder/MEMORY.md` | Modify | Feature folder, status. | C2 |

## 2) Pure/testable logic (`SettingsLogic` and updated logic)
| Logic | Inputs | Output | RF |
|---|---|---|---|
| Prefix validation | text | trimmed prefix or error (empty, `/` `:`, > 30 characters) | RF-7 |
| Session name | prefix, start date, existing names | `<prefix> YYYY-MM-DD HH.mm.ss`, `… (2)` | RF-7 |
| Default quality | rule, offered qualities | 24/48 rule (current) or 24-bit at the highest offered rate | RF-6 |
| Fade gain | frame index in ramp, ramp length, direction | 0…1 linear (1 outside ramps) | RF-4 |
| Fade length | `PauseFade`, sample rate | frames (Short 20 ms, Long 200 ms, Off 0) | RF-4 |
| Time limit | elapsed seconds, limit | reached? | RF-8 |
| Warning threshold | `LowStorageWarning` | seconds (600 / 1800 / 3600) | RF-9 |
| Held peak | previous held value + time, new peak, now, `PeakHold` | held value (decays after 1 s / 3 s; Until reset keeps max) | RF-3 |
| Segments | meter value 0…1, segment count | lit segments + zone colors | RF-2 |
| Sort | items, order | sorted (natural name compare for Name) | RF-11 |
| Storage summary | count, total bytes, free bytes | `12 sessions · 4.2 GB · 85 GB available` (singular "1 session") | RF-12 |

## 3) Technical design
### Settings storage and sharing
- One JSON value `app_settings_v1` holds all settings (versioned; unknown fields ignored, missing fields → default), plus `library_sort_order_v1`. Existing keys are unchanged (`recording_quality_by_device_v1`, `library_export_format_v1` still stores the last used choice).
- `AppSettingsStore` is created in `MyApp` and shared by every window and the Mac Settings scene, so a change in Settings updates all windows at once.
- View models read the store when they need a value (recording start, export sheet opening, meter updates), so no extra observation chains are needed beyond the views.

### Meters
- Peak hold is computed with the existing clip-hold logic in `RecordingViewModel.updateLevels` (~30 Hz, in `LevelMeterModel` only, so the rest of the UI is not redrawn).
- Segmented style: same dB scale as today (`RecordingLogic.meterValue`), ~24 segments with green/yellow/red zones.

### Fade at pause/resume (bit-exact elsewhere)
```text
pause (user):   writing continues for N frames with gain 1 → 0, then stops   (N = 20 ms or 200 ms)
resume:         first N frames written with gain 0 → 1, then gain 1 (no multiplication)
disconnect / interruption pause: stops immediately (no fade-out); resume still fades in
```
- Applied in `CaptureSampleProcessor` on the Float32 buffer just before writing, under the existing write lock.
- The pause button reacts immediately in the UI; the file simply contains the extra fade-out frames.

### Keep screen on (iOS)
- `UIApplication.shared.isIdleTimerDisabled = true` while a recording exists and the setting is on; reset on stop.

### Time limit and warning threshold
- Checked in the existing 1 s live-info update (`checkStorage`), next to the storage decision.

### Library
- Sort menu in the toolbar (`Menu` with a `Picker`), saved in `library_sort_order_v1`.
- Storage line: `safeAreaInset(edge: .bottom)` under the list; free bytes from `SessionLibraryStore.freeBytes(at:)`, total from listed file sizes.

### Theme
- `preferredColorScheme` on every window and the Settings window (nil = System).

## 4) Technical decisions and rejected alternatives
| Decision | Rejected alternative |
|---|---|
| One JSON key `app_settings_v1` for all settings. | One key per setting — more keys to version and migrate. |
| Shared `AppSettingsStore` created in `MyApp`. | Each view model reading `UserDefaults` directly — the Mac Settings window could not update open windows. |
| Fade-out continues writing for the fade length after Pause. | Rewriting already written audio — not possible safely with an open CAF writer. |
| Sort in the library toolbar (approved). | Sort in Settings. |
| Gear in both tabs + Mac Settings window (approved). | A Settings tab. |

## 5) Decisions approved before implementation (2026-11-14)
1. **New files** in `Features/Settings/` listed in §1.
2. **UserDefaults keys:** `app_settings_v1` (all settings as JSON) and `library_sort_order_v1`.
3. **Fade-out after Pause:** the recording keeps the fade length (20 or 200 ms) of audio after Pause is pressed, so the file ends smoothly.

## 6) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Pure logic | Scratch script for `SettingsLogic` and the updated recording/library logic. | RF-2–RF-12 |
| Fade | Scratch script with a synthetic signal through the processor: ramps only around pause points, identical samples elsewhere. | RF-4, NFR-4 |
| Build | `xcodebuild` macOS + iOS Simulator (scratch DerivedData). | NFR-1 |
| Previews | Settings form, meters, waveform line, storage line. | C5 |
| Real devices | iPhone + Mac: every option, persistence after restart, Settings window updating an open window, screen stays on, time limit (short limit via a debug value or waiting), prefix on new and recovered sessions. | RF-1–RF-14 |
