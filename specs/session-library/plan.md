# Plan: Session Library

## References
- `docs/constitution.md` (C1–C6)
- `specs/session-library/spec.md` (RF-1–RF-8, NFR-1–NFR-6, Decisions)
- `specs/recording/spec.md` + `plan.md` (session storage, `SessionFileStore`, Recording menu, audio session)

## 1) Files to create or modify (responsibility + RF coverage)
New feature folder: `Session Recorder/Features/SessionLibrary/` (views in `Views/`, view model files in `ViewModels/`, same pattern as `Features/Recording/`).

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Features/SessionLibrary/SessionLibraryModels.swift` | Create | Value types: `SessionItem` (URL, name, recorded date, duration, format, size, readable), `SessionFormat` (channels, sample rate, bit depth), `ExportFormat` (original/WAV/AIFF/FLAC/ALAC/AAC) + `AACBitrate`, `TrimRange`, `WaveformData` (peaks per second), library notices/errors. No I/O. | RF-1–RF-6 |
| `Features/SessionLibrary/SessionLibraryLogic.swift` | Create | **Pure logic**: sort newest first, rename validation (empty / `/` `:` / duplicate, case-insensitive), trimmed name + uniqueness, trim range rules (≥ 1 s, clamp, trimmed recorded date), export size estimate, AAC sample rate choice, waveform bucket math (peaks → bars for a width; range → bars), waveform cache key, recorded date fallback from the default name, time formatting (`H:MM:SS`, `M:SS.s` for trim). | RF-1–RF-6 |
| `Features/SessionLibrary/SessionLibraryStore.swift` | Create | File operations on `Documents/Sessions/`: list `.caf` files with info (duration/format read off the main thread), rename (move), delete (Mac: `trashItem`, iOS: `removeItem`), trim (bit-exact copy of a frame range to a temp file, set recorded date, move into Sessions with a unique name), free storage. | RF-1, RF-3, RF-4, RF-5, NFR-4 |
| `Features/SessionLibrary/WaveformService.swift` | Create | Computes peaks (10 per second, max of channels) by reading the file in chunks on a background task, reports progress, reads/writes the cache in `Caches/Waveforms/`. | RF-2, RF-5, NFR-2, NFR-3 |
| `Features/SessionLibrary/SessionPlayerService.swift` | Create | Apple-API boundary for playback: `AVAudioPlayer` (play/pause/seek/±15 s, range playback for trim), Now Playing info + remote commands (`MediaPlayer`), pauses on audio interruptions without auto-resume. | RF-2, RF-5 |
| `Features/SessionLibrary/SessionExportService.swift` | Create | Converts a session to the chosen format in a temp folder (`AVAudioFile` read → write with format settings, chunked), progress + cancel, removes partial/temporary files. | RF-6, NFR-3, NFR-4 |
| `Features/SessionLibrary/SessionLibrarySettingsRepository.swift` | Create | `UserDefaults`: last export format + AAC bitrate (`library_export_format_v1`). No personal data. | RF-6, NFR-5 |
| `Features/SessionLibrary/ViewModels/SessionLibraryViewModel.swift` | Create | List state, refresh (on appear, app active, recording saved), selection, rename, delete, pending confirmations, notices. | RF-1, RF-3, RF-4 |
| `Features/SessionLibrary/ViewModels/SessionDetailViewModel.swift` | Create | Detail of one session: info, waveform loading, player state, playback availability (disabled while a recording exists), audio session hand-off. | RF-2, RF-7 |
| `Features/SessionLibrary/ViewModels/SessionDetailViewModel+Trim.swift` | Create | Trim mode: handles, range preview, validation, save as new session. | RF-5 |
| `Features/SessionLibrary/ViewModels/SessionExportViewModel.swift` | Create | Share flow: format/bitrate, size estimate, export progress/cancel, exported file URL, cleanup. | RF-6 |
| `Features/SessionLibrary/ViewModels/SessionLibraryViewModel+Preview.swift` | Create | Preview instances for all states (no files or audio). | C5 |
| `Features/SessionLibrary/Views/SessionLibraryView.swift` | Create | Sessions tab content: `NavigationSplitView` on iPhone/iPad (collapses to a stack on iPhone); on Mac list + detail side by side in an `HStack` (a split view inside the tab sidebar laid the detail under the list), `REC` indicator, empty state, swipe/context actions, rename alert, delete confirmation. | RF-1, RF-3, RF-4, NFR-1 |
| `Features/SessionLibrary/Views/SessionRow.swift` | Create | Name, date, duration (or "Can't be played"). | RF-1 |
| `Features/SessionLibrary/Views/SessionDetailView.swift` | Create | Info, waveform, player controls, actions (Trim, Share, Rename, Delete, Show in Finder on Mac). | RF-2–RF-7 |
| `Features/SessionLibrary/Views/WaveformView.swift` | Create | Draws peaks (Canvas), playback position, tap/drag to seek, optional trim handles and dimmed outside range; loading state. | RF-2, RF-5 |
| `Features/SessionLibrary/Views/PlayerControlsView.swift` | Create | Play/pause, ±15 s, elapsed/total time; disabled state with reason. | RF-2 |
| `Features/SessionLibrary/Views/TrimControlsView.swift` | Create | Start/end/resulting duration, play range, Cancel / Save as New Session. | RF-5 |
| `Features/SessionLibrary/Views/ExportSheet.swift` | Create | Format + bitrate pickers, size estimate, Export → progress → `ShareLink` (all platforms) and **Save…** (`fileExporter`, Mac). | RF-6 |
| `Features/SessionLibrary/Views/SessionLibraryCommands.swift` | Create | Mac/iPad keyboard: Play/Pause (Space), Skip Back/Forward (⌘← / ⌘→), Rename…, Delete (⌘⌫), via `@FocusedObject`. | RF-8 |
| `Features/SessionLibrary/Views/SessionLibraryViews+Previews.swift` | Create | `#Preview` for list (empty / sessions / unreadable / recording indicator), detail (loading / ready / playing / disabled while recording), trim, export (choose / progress / ready / error), rename/delete dialogs. | C5 |
| `Features/Recording/ViewModels/RecordingViewModel.swift` | Modify | Publish saved/recovered session events for the library; stop idle meters while playback is active (`setPlaybackActive`); Record unavailable while playing. | RF-1, RF-2 |
| `Features/AudioDevicesList/AudioInputDeviceService.swift` | Modify | iOS audio session for playback: `.playback` (not mixable, so Now Playing and background playback work) while playing; back to `.playAndRecord`/`.measurement` after, on the session queue. | RF-2 |
| `Features/Recording/SessionFileStore.swift` | Modify | Expose the default Sessions directory (shared with the library store) so both use the same location. | RF-1 |
| `ContentView.swift` | Modify | Own `SessionLibraryViewModel`; Sessions tab shows `SessionLibraryView`; selecting the Record tab stops playback; `focusedSceneObject` for library commands. | RF-1, RF-2, RF-8 |
| `MyApp.swift` | Modify | `.commands { SessionLibraryCommands() }`. | RF-8 |
| `Session Recorder.xcodeproj/project.pbxproj` (or `Session-Recorder-Info.plist`) | Modify (approved 2026-11-14) | iOS: `UIFileSharingEnabled = YES`, `LSSupportsOpeningDocumentsInPlace = YES` so Documents is visible in Files. | RF-7 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `Session Recorder/MEMORY.md` | Modify | Code layout, status. | C2 |

## 2) Pure/testable logic (`SessionLibraryLogic`)
| Logic | Inputs (explicit) | Output | RF |
|---|---|---|---|
| Sort | items | newest recorded date first; name as tie-breaker | RF-1 |
| Recorded date | file creation date?, file name | creation date; else date parsed from `Session YYYY-MM-DD HH.mm`; else modification date | RF-1 |
| Rename validation | new name, current name, existing names | ok(trimmed) / empty / invalid characters (`/`, `:`) / duplicate (case-insensitive; same session ignored) | RF-3 |
| Trimmed name | original name, existing names | `<name> (trimmed)`, `<name> (trimmed 2)`… | RF-5 |
| Trim range | start, end, duration | clamped to `0…duration`, start < end, valid when `end − start ≥ 1 s`; frame range for a sample rate | RF-5 |
| Trimmed recorded date | original date, start offset | `date + start` | RF-5 |
| Export size estimate | format, bitrate, duration, session format | PCM formats exact (`rate × bits/8 × ch × s`), FLAC/ALAC ≈ 60 % of PCM ("About"), AAC `bitrate × s / 8` | RF-6 |
| AAC sample rate | session rate | session rate if ≤ 48 kHz, else 48 kHz | RF-6 |
| Waveform bars | peaks (10/s), visible range, bar count | max per bar (0…1), same scale as the meters | RF-2, RF-5 |
| Position ↔ x | time, duration, width | x; inverse for tap/drag seek | RF-2, RF-5 |
| Waveform cache key | creation date, file size, modification date | stable string; unchanged on rename, changes when the audio changes | RF-2 |
| Formatting | seconds | `H:MM:SS` / `M:SS` for player, `M:SS.s` for trim handles | RF-2, RF-5 |

## 3) Technical design
### Files and dates
```text
Documents/Sessions/<name>.caf              sessions (visible in Files on iOS, Finder via Show in Finder on Mac)
Library/Caches/Waveforms/<key>.peaks       waveform cache (UInt8 peaks, 10 per second; ~36 KB per hour)
tmp/Export/<uuid>/<name>.<ext>             exported file while sharing; removed after sharing/cancel and at launch
Application Support/InProgress/            recording in progress (recording feature, never listed)
```
- **Recorded date = file creation date.** The recording file is created when recording starts and moved (moving keeps the creation date), so no metadata file is needed and renaming keeps the date. Trim sets the new file's creation date to `original + start`. Fallbacks: the default name pattern, then the modification date.
- **Durations and formats** are read from the CAF header (`AVAudioFile` length/format) on a background task; the list shows rows immediately and fills durations as they arrive (NFR-2).
- **Changes outside the app:** the list refreshes when the app becomes active and after every own operation (no folder watcher, C1).

### Playback and the audio session
- `AVAudioPlayer` per opened session (streams from disk; memory does not grow with length, NFR-3).
- **iOS:** recording meters keep the session in `.playAndRecord`/`.measurement` with `.mixWithOthers`. A mixable session cannot own Now Playing and would play through the receiver. While playing: the recording view model stops idle capture, then the device service switches to `.playback` (not mixable). When playback stops or the detail closes: back to the recording configuration and meters restart. All session calls stay on the service's serial queue.
- **While a recording exists**, playback is disabled (spec RF-2). **While playing**, Record is unavailable; selecting the Record tab stops playback, so recording always starts from the normal configuration.
- **Now Playing:** title = session name, duration, elapsed time, play/pause/skip remote commands. Audio interruptions pause playback; no automatic resume.
- **Mac:** no audio session; Now Playing and remote commands also work.

### Waveform
- 10 peaks per second (max absolute value of all channels, quantized to 0…255). A 4 h session = 144 000 bytes. Enough for the detail and for trim handles (100 ms resolution; trim times are shown exactly).
- Computed in chunks of about 1 s on a background task, publishing partial results so the waveform fills left to right (RF-2). Cancelled when the detail closes. Saved to the cache when complete.

### Trim (bit-exact)
- Read the frame range with `AVAudioFile` in chunks and write a new CAF with the **same** settings (format, bit depth, channels): PCM in = PCM out, so samples are identical (spec RF-5). Written in a temp file and moved into `Sessions/` at the end; a failure removes the temp file (NFR-4).
- Free storage checked first (range bytes + margin).

### Export
| Format | Extension | Settings |
|---|---|---|
| Original | `.caf` | file copy |
| WAV | `.wav` | linear PCM, same rate/bits/channels, little-endian |
| AIFF | `.aiff` | linear PCM, same rate/bits/channels, big-endian |
| FLAC | `.flac` | `kAudioFormatFLAC`, same rate/bits/channels |
| ALAC | `.m4a` | `kAudioFormatAppleLossless`, same rate/bits/channels |
| AAC | `.m4a` | `kAudioFormatMPEG4AAC`, chosen bitrate, rate per §2 |
- Converted in chunks off the main thread with progress (frames written / total) and a cancel flag checked per chunk.
- After export: `ShareLink(item: url)` opens the system share sheet (iOS/iPadOS/Mac); on Mac also **Save…** with `fileExporter`. The temp folder is removed when the sheet closes and on launch.

### Delete
- Mac: `FileManager.trashItem` (restorable from Finder). iOS/iPadOS: `removeItem` after a confirmation that says it cannot be undone.
- The waveform cache entry is removed too.

### Files/Finder
- iOS: `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` make `Documents` visible in Files. Only `Sessions/` lives there (in-progress files are in Application Support).
- Mac: **Show in Finder** uses `NSWorkspace.activateFileViewerSelecting`.

## 4) State (`SessionDetailViewModel`)
```text
loading info ──▶ ready(stopped) ──play──▶ playing ──pause──▶ ready(paused)
ready|playing ──trim──▶ trimming (playback of range only) ──save──▶ new session opened | cancel ──▶ ready
any ──recording exists──▶ playback disabled (stopped)
any ──Record tab selected / detail closed / session deleted──▶ stopped (audio session restored)
```

## 5) UI
| UI area | Behavior | RF |
|---|---|---|
| Sessions tab | `REC` indicator (recording RF-4) above the list; list newest first; empty state when none. iPhone: list → detail push; iPad/Mac: list + detail side by side. | RF-1, NFR-1 |
| Row | Name, `12 Nov 2026, 22:30 · 1:02:15`; "Can't be played" for unreadable files. Swipe: Delete, Rename. Context menu: Rename, Share, Delete (and Show in Finder on Mac). | RF-1, RF-3, RF-4, RF-6 |
| Detail | Name (title), date, duration, `Stereo · 24-bit/48 kHz · 1.04 GB`; waveform; player; toolbar/menu: Trim, Share, Rename, Delete, Show in Finder (Mac). | RF-2–RF-7 |
| Trim | Handles on the waveform; start/end/duration labels; Play Selection; Cancel / Save as New Session. | RF-5 |
| Share sheet | Format picker, AAC bitrate (only for AAC), "About 412 MB", Export → progress + Cancel → Share… (+ Save… on Mac). | RF-6 |
| Rename | Alert with text field, inline validation message. | RF-3 |
| Delete | Confirmation dialog naming the session; iOS text says it cannot be undone; Mac says it moves to the Trash. | RF-4 |
| Mac menu | **Session** menu: Play/Pause (Space), Skip Back (⌘←), Skip Forward (⌘→), Rename…, Delete (⌘⌫), Show in Finder. Space for playback is enabled only when no recording exists and no rename is in progress; the Recording menu's Space is enabled only while a recording exists, so they never overlap. | RF-8 |
| Accessibility | Waveform exposes position as an adjustable value; buttons have labels; large Dynamic Type supported. | NFR-1 |

## 6) Technical decisions and rejected alternatives
| Decision | Rejected alternative |
|---|---|
| Recorded date from the file creation date (no metadata file). | A metadata JSON per session or a CAF info chunk — a new persisted format for one value (C1). |
| `AVAudioPlayer` for playback. | `AVAudioEngine` player node — more control than needed; `AVPlayer` — no benefit for local CAF. |
| `.playback` session only while playing, meters stopped meanwhile. | Keeping `.playAndRecord` + `.mixWithOthers` — no Now Playing/background playback and receiver output on iPhone. |
| Waveform peaks cached in Caches (approved 2026-11-14). | Computing on every open (seconds for long sessions); storing next to the session (would appear in Files). |
| Trim and export with `AVAudioFile` chunked read/write. | `AVAssetExportSession` — no FLAC/AIFF/WAV control and not bit-exact for trim. |
| Two-step share (Export, then Share) with `ShareLink`. | Presenting a UIKit/AppKit share controller directly — platform-specific code for little gain. |
| Separate `SessionLibraryViewModel` / `SessionDetailViewModel`; library talks to recording only through a saved-session event and the playback hand-off. | Putting library state in `RecordingViewModel` (C4). |
| Refresh on app active + after own operations. | Folder monitoring with `DispatchSource` — more code; not required by the spec. |

## 7) Decisions approved before implementation (2026-11-14)
1. **New files** listed in §1 (feature folder `Features/SessionLibrary/`).
2. **Info.plist keys (iOS):** `UIFileSharingEnabled = YES`, `LSSupportsOpeningDocumentsInPlace = YES` (via build settings if the generated Info.plist supports them, otherwise in `Session-Recorder-Info.plist`).
3. **UserDefaults key:** `library_export_format_v1` (export format + AAC bitrate).
4. **Waveform cache format:** `Caches/Waveforms/<key>.peaks`, raw UInt8 peaks (10 per second) with a small header (version, peaks per second).
5. **Recorded date from the file creation date** (trim sets it on the new file).
6. **Playback/recording hand-off:** meters stop and Record is unavailable while playing; selecting the Record tab stops playback.

## 8) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Pure logic | Scratch script compiling `SessionLibraryLogic.swift` + models with sample inputs. | RF-1–RF-6 |
| File operations | Scratch script on a temp folder: list, rename, delete, trim (compare samples of the trimmed range with the original), export each format (`afinfo`), cleanup of temp files. | RF-1, RF-3–RF-6, NFR-4 |
| Build | `xcodebuild` for macOS and an iOS Simulator (see `AGENTS.md`). | NFR-1 |
| Previews | All UI states with preview view models (no files or audio). | C5 |
| Real devices | iPhone + Mac (+ iPad if available): list after recording, playback with lock screen controls, interruptions, rename/delete (Trash on Mac), trim, export every format and open it in another app, Files visibility, Show in Finder, Mac shortcuts with and without a recording, a ≥ 1 h session. | RF-1–RF-8, NFR-2, NFR-3 |
