# Tasks: Recording

Source: `specs/recording/spec.md`, `specs/recording/plan.md`.
Constraints: C1–C6 (SwiftUI/Apple APIs only, no deps, logic separated from UI, no personal data in persistence, English text). Keep tasks small (20–30 min), in dependency order. Paths are relative to `Session Recorder/`.

## Tasks

- [x] **T1 — Recording models** (`Features/Recording/RecordingModels.swift`)
  - **RF:** RF-1–RF-8
  - **Depends on:** none
  - **Done when:** Value types exist for quality (sample rate, bit depth, label), recording state (idle / recording / paused with reason), live info (elapsed, bytes, remaining), channel level (peak, clipping) and notices; no I/O.

- [x] **T2 — Pure recording logic** (`Features/Recording/RecordingLogic.swift`)
  - **RF:** RF-1–RF-6, RF-8
  - **Depends on:** T1
  - **Done when:** Pure functions cover offered rates/qualities (incl. 48 kHz fallback), quality resolution (saved vs. highest), bytes/s, remaining time, can-start (incl. < 1 min storage), storage decision (warn ≤ 10 min once, stop ≤ 1 min), session name + uniqueness (`Session YYYY-MM-DD HH.mm (2)`), can-resume, clip hold (2 s), meter value, and formatting; verified with a scratch script.

- [x] **T3 — Recording settings repository** (`Features/Recording/RecordingSettingsRepository.swift`)
  - **RF:** RF-1, RF-3, NFR-5
  - **Depends on:** T1
  - **Done when:** Per-device quality and the DND-tip flag are read/written in `UserDefaults` with versioned keys; device IDs and numbers only.

- [x] **T4 — Supported sample rates per device** (`Features/AudioDevicesList/AudioDeviceModels.swift`, `AudioInputDeviceService.swift`)
  - **RF:** RF-1
  - **Depends on:** none
  - **Done when:** `AudioInputDevice` exposes the device's supported sample rates on Mac and iOS; previews and existing behavior unchanged; builds on both platforms.

- [x] **T5 — Capture service: live levels (+ iOS capture spike)** (`Features/Recording/AudioCaptureService.swift`)
  - **RF:** RF-2, NFR-6
  - **Depends on:** T1, T2
  - **Done when:** For the selected device and channels the service publishes per-channel peaks while idle; verified on a real Mac and iPhone/iPad with the mixer. The iOS capture API decision (AVCaptureSession vs. AVAudioEngine) is recorded in `plan.md` §3, including native format/bit depth seen on device.
  - **Result (2026-11-12):** macOS verified with the Xone (meters OK). iOS delivered Int16 interleaved and did not list the Xone → iOS moves to AVAudioSession discovery (T5b) and AVAudioEngine capture (T5c).

- [x] **T5b — iOS device discovery and routing with AVAudioSession** (`Features/AudioDevicesList/AudioInputDeviceService.swift`, `ViewModels/AudioSourceSelectionViewModel+DeviceSelection.swift`)
  - **RF:** audio-devices-list RF-1–RF-3, RF-7; recording RF-1
  - **Depends on:** T4
  - **Done when:** On a real iPhone/iPad the Xone appears with its name and all its input channels; selecting a device routes input to it; connect/disconnect follows RF-7; the built-in mic still works; macOS unchanged.

- [x] **T5c — iOS capture with AVAudioEngine** (`Features/Recording/AudioCaptureService.swift`)
  - **RF:** RF-2, NFR-6
  - **Depends on:** T5, T5b
  - **Done when:** On iOS, meters use an `AVAudioEngine` input tap on the routed device (Float32), mono and stereo, for the Xone and the built-in mic; the debug `Capture:` line shows the format; macOS keeps `AVCaptureSession`.

- [x] **T6 — Session file store** (`Features/Recording/SessionFileStore.swift`)
  - **RF:** RF-3, RF-6, RF-8, NFR-3, NFR-4
  - **Depends on:** T1, T2
  - **Done when:** Creates folders, creates the in-progress CAF (PCM, quality, 1/2 channels), finalizes (move to `Documents/Sessions/` with a unique name), discards empty files, lists leftovers for recovery, and reports free storage.

- [x] **T7 — Capture service: write, pause/resume** (`Features/Recording/AudioCaptureService.swift`)
  - **RF:** RF-3, RF-5, NFR-2
  - **Depends on:** T5, T5c, T6
  - **Done when:** Selected channels are converted to the selected quality (only when the device rate differs) and written on the capture queue; pause stops writing without stopping meters; resume continues in the same file; written frame count is exposed.

- [x] **T8 — Recording view model** (`Features/Recording/ViewModels/RecordingViewModel.swift`)
  - **RF:** RF-1, RF-3–RF-6
  - **Depends on:** T2, T3, T7
  - **Done when:** State machine idle/recording/paused works; start checks can-start and shows errors; live info updates every second; stop saves and shows "Saved: …"; empty recordings discarded; `isSourceLocked` set while a recording exists; quality resolved and saved per device.

- [x] **T9 — Record tab UI: meters, status, controls** (`Features/Recording/Views/LevelMetersView.swift`, `RecordingStatusView.swift`, `RecordingControlsView.swift`, `ContentView.swift`)
  - **RF:** RF-2–RF-6, NFR-1
  - **Depends on:** T8
  - **Done when:** Record tab shows meters (mono/L-R, clipping), status (`REC`/`PAUSED`, elapsed, size, remaining), Record / Pause-Resume / Stop; controls pinned at the bottom; `RecordButton` no longer used.

- [x] **T10 — Quality in source sheet and row; locked row** (`Features/Recording/Views/RecordingQualitySection.swift`, `Features/AudioDevicesList/Views/AudioSourceSelectionView.swift`, `AudioSourceSummaryRow.swift`)
  - **RF:** RF-1, RF-4
  - **Depends on:** T8
  - **Done when:** The sheet has a Quality section limited to offered options; the row shows quality; while recording/paused the row cannot open the sheet.
  - **Result:** Also fixed on iPhone: session changes (route, rate, channels) are serialized and tracked (`isRoutingInput`), the engine restarts on one queue, device discovery runs off the main thread, meter levels live in `LevelMeterModel` so menus are not rebuilt 30×/s, and channel lists became menus (Channel / Left / Right).

- [x] **T11 — REC indicator on Sessions tab** (`Features/Recording/Views/RecordingIndicator.swift`, `ContentView.swift`)
  - **RF:** RF-4
  - **Depends on:** T9
  - **Done when:** While recording/paused the Sessions tab shows `REC`/`PAUSED` + elapsed; tapping it selects the Record tab.

- [x] **T12 — Interruptions: disconnect and iOS audio interruptions** (`Features/Recording/ViewModels/RecordingViewModel+Interruptions.swift`, `AudioCaptureService.swift`)
  - **RF:** RF-8
  - **Depends on:** T8
  - **Done when:** Unplugging pauses with a notice, Resume is disabled until the same device returns, Stop saves; calls/other apps pause on iOS and never auto-resume; Mac keeps recording; capture runtime errors stop and save.

- [x] **T13 — Low storage and recovery after termination** (`RecordingViewModel+Interruptions.swift`, `SessionFileStore.swift`, `MyApp.swift`)
  - **RF:** RF-8, NFR-4
  - **Depends on:** T6, T8
  - **Done when:** Warning once at ~10 min left; auto stop + save + notice at ~1 min; on launch, leftover in-progress files with audio become sessions with a recovery notice (empty ones are deleted).
  - **Result:** Recovery runs once per process from `RecordingViewModel.attach` (no `MyApp.swift` change needed).

- [x] **T14 — Background recording and Mac sleep** (Xcode: Background Modes → Audio; `RecordingViewModel.swift`)
  - **RF:** RF-7
  - **Depends on:** T8
  - **Done when:** `UIBackgroundModes = audio` set for iOS; recording continues with the iPhone locked / app in background; idle capture stops in background when not recording; Mac does not idle-sleep while recording.

- [x] **T15 — Do Not Disturb tip** (`Features/Recording/Views/RecordingStatusView.swift` or `ContentView.swift`)
  - **RF:** RF-3
  - **Depends on:** T3, T9
  - **Done when:** On iPhone/iPad the first recording shows a dismissible tip; after dismissing it never appears again; not shown on Mac.

- [x] **T16 — Mac Recording menu and shortcuts** (`Features/Recording/Views/RecordingCommands.swift`, `MyApp.swift`, `ContentView.swift`)
  - **RF:** RF-9
  - **Depends on:** T9
  - **Done when:** Recording menu with Record/Stop (⌘R), Pause/Resume (Space), Choose Source… (no shortcut); items enabled only when possible; Space does not fire inside text fields; iPad hardware keyboard works where supported.

- [x] **T17 — Previews** (`Features/Recording/ViewModels/RecordingViewModel+Preview.swift`, `Features/Recording/Views/RecordingViews+Previews.swift`, `ContentView.swift`)
  - **RF:** RF-1–RF-8, C5
  - **Depends on:** T9–T13, T15
  - **Done when:** Previews exist for idle with meters (mono/stereo, clipping), recording, paused (user / disconnected / interruption), low storage warning, saved/recovered notices, quality section, locked row, Sessions indicator, DND tip.
  - **Result:** Quality previews live in `RecordingViews+Previews.swift`; Record tab states in `ContentView.swift`; preview view models never start capture or touch files.

- [x] **T18 — Cleanup and docs** (`RecordButton.swift`, `CONSTANTS.swift`, `AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2
  - **Depends on:** T9
  - **Done when:** `RecordButton.swift` and `STATUSES` are removed; docs list `Features/Recording/`, the storage decision, and the updated status.

- [ ] **T19 — Verification pass**
  - **RF:** RF-1–RF-9, NFR-1–NFR-7
  - **Depends on:** T1–T18
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; manual checks on a real Mac and iPhone/iPad with the mixer and the built-in mic cover every Completion Criterion in the spec, including a ≥ 1 h recording and checking file format/rate/bit depth in another app.
