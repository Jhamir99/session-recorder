# Plan: Recording

## References
- `docs/constitution.md` (C1–C6)
- `specs/recording/spec.md` (RF-1–RF-9, NFR-1–NFR-7, Decisions)
- `specs/audio-devices-list/spec.md` (RF-6 source row/sheet, RF-7 source lock)

## 1) Files to create or modify (responsibility + RF coverage)
New feature folder: `Session Recorder/Features/Recording/` (views in `Views/`, view model files in `ViewModels/`, same pattern as `Features/AudioDevicesList/`).

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Features/Recording/RecordingModels.swift` | Create | Value types: `RecordingQuality` (sample rate, bit depth), recording state (idle / recording / paused with reason: user, device disconnected, interruption), live info (elapsed, file bytes, remaining seconds), channel level (peak, clipping), recording notices. No I/O. | RF-1–RF-8 |
| `Features/Recording/RecordingLogic.swift` | Create | **Pure logic** (explicit inputs, incl. dates/free bytes): offered qualities, default/saved quality resolution, session name + uniqueness, bytes per second, remaining time, low-storage decisions, clip-hold decision, peak → meter value, `H:MM:SS` and file-size formatting, can-record / can-resume rules. | RF-1–RF-6, RF-8 |
| `Features/Recording/RecordingSettingsRepository.swift` | Create | `UserDefaults`: per-device quality (`recording_quality_by_device_v1`, device ID → sample rate + bit depth) and Do Not Disturb tip flag (`recording_dnd_tip_dismissed_v1`). No personal data (keys approved 2026-11-12). | RF-1, RF-3, NFR-5 |
| `Features/Recording/AudioCaptureService.swift` | Create | Apple-API boundary: open the selected device, extract selected channels, publish levels (idle and recording), convert to the selected quality, hand PCM buffers to the writer; pause/resume writing; observe capture interruptions (iOS audio session interruption, capture session runtime errors). | RF-2, RF-3, RF-5, RF-8 |
| `Features/Recording/SessionFileStore.swift` | Create | Files: `Documents/Sessions/` (final sessions), `Application Support/InProgress/` (current recording). Create/write CAF PCM file, finalize (move + unique name), discard empty, recover leftovers on launch, free storage. | RF-3, RF-6, RF-8, NFR-3, NFR-4 |
| `Features/Recording/ViewModels/RecordingViewModel.swift` | Create | Coordinates capture service + file store + logic + settings; state machine; live info timer; locks the source (`AudioSourceSelectionViewModel.isSourceLocked`); Mac sleep prevention. | RF-1–RF-8 |
| `Features/Recording/ViewModels/RecordingViewModel+Interruptions.swift` | Create | Device disconnect/reconnect, iOS interruptions, low storage, recovery notice. | RF-8 |
| `Features/Recording/ViewModels/RecordingViewModel+Preview.swift` | Create | Preview instances for all states (no hardware). | C5 |
| `Features/Recording/Views/LevelMetersView.swift` | Create | One meter (mono) or L/R meters (stereo), clipping indicators. | RF-2 |
| `Features/Recording/Views/RecordingControlsView.swift` | Create | Record button (idle), Pause/Resume + Stop (recording/paused). Replaces `RecordButton`. | RF-3, RF-5, RF-6 |
| `Features/Recording/Views/RecordingStatusView.swift` | Create | `REC`/`PAUSED`, elapsed time, file size, remaining time, notices. | RF-4, RF-8 |
| `Features/Recording/Views/RecordingIndicator.swift` | Create | Compact `REC`/`PAUSED` + elapsed for the Sessions tab; tap returns to Record tab. | RF-4 |
| `Features/Recording/Views/RecordingQualitySection.swift` | Create | Quality section for the source sheet (sample rate + bit depth pickers). | RF-1 |
| `Features/Recording/Views/RecordingCommands.swift` | Create | Mac **Recording** menu + shortcuts via `@FocusedObject`. | RF-9 |
| `Features/Recording/Views/RecordingViews+Previews.swift` | Create | `#Preview` for meters, controls, status, indicator, quality section. | C5 |
| `Features/AudioDevicesList/AudioDeviceModels.swift` | Modify | Add `supportedSampleRates: [Double]` to `AudioInputDevice`. | RF-1 |
| `Features/AudioDevicesList/AudioInputDeviceService.swift` | Modify | Fill `supportedSampleRates` from the device formats. | RF-1 |
| `Features/AudioDevicesList/Views/AudioSourceSelectionView.swift` | Modify | Add `RecordingQualitySection` after Channels. | RF-1 |
| `Features/AudioDevicesList/Views/AudioSourceSummaryRow.swift` | Modify | Show quality in the subtitle; when locked, show the source without opening the sheet. | RF-1, RF-4 |
| `ContentView.swift` | Modify | Own `RecordingViewModel`; Record tab: row, messages, meters, status, controls; Sessions tab: indicator; tab selection binding; `focusedSceneObject`. | RF-2–RF-6, RF-9 |
| `MyApp.swift` | Modify | `.commands { RecordingCommands() }`; trigger recovery on launch. | RF-8, RF-9 |
| `RecordButton.swift`, `STATUSES` in `CONSTANTS.swift` | Delete (approved 2026-11-12) | Replaced by `RecordingControlsView` and the recording state. | RF-3 |
| `Session Recorder.xcodeproj/project.pbxproj` | Modify (via Xcode; approved 2026-11-12) | iOS **Background Modes → Audio** (`UIBackgroundModes = audio`). | RF-7 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `Session Recorder/MEMORY.md` | Modify | Code layout, status, storage decision. | C2 |

## 2) Pure/testable logic (`RecordingLogic`)
| Logic | Inputs (explicit) | Output | RF |
|---|---|---|---|
| Offered sample rates | device supported rates | `[44100, 48000, 88200, 96000] ∩ supported`, or `[48000]` if empty | RF-1 |
| Offered qualities | offered rates | rates × `[16, 24]` bits | RF-1 |
| Resolve quality | saved quality?, offered qualities | saved if offered, else 24/48 (or 24-bit at highest rate ≤ 48 kHz, else lowest) | RF-1 |
| Bytes per second | quality, channel count | `rate × bits/8 × channels` | RF-4 |
| Remaining seconds | free bytes, bytes/s | free / bytes/s (≥ 0) | RF-4 |
| Can start | permission, valid selection, remaining seconds | allowed, or error reason (`< 60 s` → not enough storage) | RF-3 |
| Storage decision | remaining seconds, warning already shown | none / warn (≤ 600 s, once) / stop (≤ 60 s) | RF-8 |
| Session name | start date, calendar/time zone, existing names | `Session YYYY-MM-DD HH.mm.ss`, `… (2)` when taken | RF-6 |
| Can resume | pause reason, recording device connected | Resume enabled? | RF-8 |
| Clip hold | last clip time, now | clip indicator visible (`< 2 s`) | RF-2 |
| Meter value | peak (linear) | 0…1 on a dB scale (e.g., −60 dBFS…0) | RF-2 |
| Formatting | seconds / bytes / remaining | `H:MM:SS`, `412 MB`, `About 5 h left` | RF-4 |

## 3) Audio pipeline (technical design)
```text
selected device + channels + quality
  └─ AudioCaptureService (capture queue)
       capture buffers (device native format, all channels)
       → extract selected channel(s) → Float32 (mono or L/R)
       → peaks per channel → levels publisher (main, ~20–30 Hz)
       → if writing: AVAudioConverter to quality rate (only if device rate differs)
                    → AVAudioFile (CAF, linear PCM Int16/Int24, interleaved) .write
```
- **Capture API (decided 2026-11-12 after the T5 spike):**
  - **macOS:** `AVCaptureSession` + `AVCaptureAudioDataOutput` with `audioSettings` = Float32 non-interleaved. Verified with the user's Xone mixer: works, meters correct.
  - **iOS:** `AVAudioEngine` (input node tap) with `AVAudioSession` (`.playAndRecord`, mode `.measurement`, preferred input = selected port, all input channels opened). Rejected `AVCaptureSession` on iOS: on a real iPhone it delivered **Int16 interleaved** (no real 24-bit), and `AVCaptureDevice` only exposes a generic microphone that follows the route, so the Xone did not appear with its name or channels.
  - **iOS device discovery (T5b):** `AudioInputDeviceService` lists `AVAudioSession.availableInputs` on iOS (ID = port UID; external = `.usbAudio`; channels from the current route; supported rate = current hardware rate). macOS keeps `AVCaptureDevice`. Device IDs saved on iOS before this change are not restored (one time; no migration).
  - Multichannel devices: build `AVAudioFormat` from the stream description with a discrete channel layout (`AVAudioFormat(cmAudioFormatDescription:)` returns nil for > 2 channels without a layout and crashed).
- **Writing:** `AVAudioFile` with CAF settings (`kAudioFormatLinearPCM`, 16/24-bit, chosen rate, 1 or 2 channels). Written on the capture queue (never the main thread). CAF needs no final header for readability, so audio before a crash is kept (NFR-4).
- **Pause:** capture keeps running (meters stay live); buffers are simply not written. Resume writes again to the same file → no gap, no extra file (RF-5).
- **Meters while idle:** capture runs without a writer while a valid source + permission exist and the Record tab is visible / app is active (NFR-6: capture stops when the app is in the background and idle).
- **Hardware sample rate:** the device runs at the quality's rate when supported (iOS: `setPreferredSampleRate` on the session queue; supported rates probed per device on routing. macOS: Core Audio `kAudioDevicePropertyNominalSampleRate`, system-wide). Otherwise the capture thread resamples.
- **Free storage:** `volumeAvailableCapacityForImportantUsage` (fallback `volumeAvailableCapacity`) of the Documents volume, checked every second while recording.
- **Mac sleep:** `ProcessInfo.beginActivity(options: .idleSystemSleepDisabled)` on start, `endActivity` on stop.

## 4) Files and recovery
```text
Documents/Sessions/Session 2026-11-11 22.30.caf          (final; visible in Files/Finder later)
Application Support/InProgress/2026-11-11T22-30-05.caf   (current recording; start date in name)

start: create InProgress file → write
stop:  if frames == 0 → delete; else move to Sessions/ with unique name → "Saved: <name>"
launch: for each InProgress file → if it has audio: move to Sessions/ (name from date in file name)
        and show "Recovered an interrupted recording: <name>"; else delete
```
The in-progress name carries the start date, so no extra persisted state is needed.

## 5) State machine (`RecordingViewModel`)
```text
idle ──record (canStart)──▶ recording
recording ──pause──▶ paused(user)
recording ──device disconnected──▶ paused(deviceDisconnected)   + notice
recording ──iOS interruption began──▶ paused(interruption)        + notice
paused(any) ──resume (canResume)──▶ recording
recording|paused ──stop | storage limit──▶ idle (save)            + notice
on enter recording|paused: audioSource.isSourceLocked = true; row locked
on enter idle:             audioSource.isSourceLocked = false; RF-7 rules apply again
```
- Elapsed time = written frames / sample rate (exact; paused time excluded).
- Interruptions (T12): capture pauses writing on the notification thread (no audio from a fallback input is written), then the view model pauses with a notice. iOS disconnect = route change `oldDeviceUnavailable` for the recording port; iOS interruption = `didBecomeInactiveNotification` with system source, ended = `resumptionRecommendationNotification` (iOS 27 API; capture restarts, recording stays paused). Mac disconnect = `AVCaptureDevice.wasDisconnectedNotification`; runtime error with the device connected = stop and save. When the same device reconnects it is reselected without a notice and capture restarts; Resume waits until routing finished.
- Permission revoked while recording: iOS terminates the app → recovery on next launch (RF-8). On Mac, a capture runtime error → stop and save.

## 6) UI
| UI area | Behavior | RF |
|---|---|---|
| Source row | `Device · Stereo · 1–2 · 24-bit/48 kHz`; locked (no chevron, no sheet) while recording/paused. | RF-1, RF-4 |
| Source sheet | New **Quality** section: Sample rate picker, Bit depth picker. | RF-1 |
| Record tab idle | Row, messages, meters, Record button (disabled when not allowed). | RF-2, RF-3 |
| Record tab recording/paused | Row (locked), meters, status (`REC`/`PAUSED`, elapsed, size, remaining), notices, Pause/Resume + Stop. | RF-4, RF-5, RF-8 |
| Sessions tab | Indicator above the empty state while recording/paused; tap → Record tab. | RF-4 |
| DND tip | Dismissible inline tip on first recording (iPhone/iPad only). | RF-3 |
| Mac menu | **Recording**: Record/Stop (⌘R), Pause/Resume (Space), Choose Source… (no shortcut). | RF-9 |
| Accessibility | Meters expose level/clipping as values; controls have labels; large Dynamic Type supported. | NFR-1 |

## 7) Technical decisions and rejected alternatives
| Decision | Rejected alternative |
|---|---|
| CAF/PCM written directly with `AVAudioFile` (approved storage decision). | `AVAudioRecorder` — cannot select a device/channels or pause into the same file with live meters reliably across platforms. |
| One `.caf` per session in `Documents/Sessions/`, name = file name, no metadata file (approved 2026-11-12). | Metadata JSON/SwiftData now — not needed until the library feature (C1). |
| In-progress file in Application Support, moved on stop. | Writing straight into `Sessions/` — half-finished files would appear in Files and recovery could not be detected. |
| Pause = stop writing, keep capture running. | Stopping capture on pause — meters would disappear and restart could glitch. |
| Quality saved per device (approved). | Global quality setting. |
| Separate `RecordingViewModel`; talks to `AudioSourceSelectionViewModel` only through `isSourceLocked` and the current selection. | Adding recording to the audio-source view model — mixes two features (C4). |
| Mac menu through `@FocusedObject` / `focusedSceneObject`. | Moving view model ownership into `MyApp` — larger change for no benefit. |
| Delete `RecordButton.swift` and `STATUSES` (approved 2026-11-12). | Keeping unused code next to the new controls. |

## 8) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Pure logic | Scratch script compiling `RecordingLogic.swift` with sample inputs (same approach as `audio-devices-list`), or a native test target only if it becomes valuable. | RF-1–RF-6, RF-8 |
| Build | `xcodebuild` for macOS and an iOS Simulator destination (see `AGENTS.md`). | NFR-1 |
| Previews | All UI states with preview view models (no hardware). | C5 |
| Real devices | Mac + iPhone/iPad with the user's mixer and the built-in mic: meters, quality, pause/resume (no gaps), stop/save/naming, locked phone, unplug/replug, call, Mac menu, ≥ 1 h recording; open the CAF files in another app to check format/rate/bit depth. | RF-1–RF-9, NFR-2, NFR-3 |
| Simulated low storage / crash | Debug-only lower thresholds or quitting the app during recording (Xcode stop), then relaunch. | RF-8, NFR-4 |
