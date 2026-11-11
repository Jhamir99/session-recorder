# Tasks: Audio Devices List and Channel Selection

Source: `specs/audio-devices-list/spec.md`, `specs/audio-devices-list/plan.md`.  
Constraints: C1–C6 (SwiftUI/Apple APIs only, no deps, logic separated from UI, no personal data in persistence, English text). Keep tasks small (20–30 min), in dependency order.

## Tasks

- [x] **T1 — Create models and value types** (`Session Recorder/Features/AudioDevicesList/AudioDeviceModels.swift`)
  - **RF:** RF-1, RF-2, RF-3, RF-4, RF-5
  - **Depends on:** none
  - **Done when:** Value types exist for device identity/display name, channel (number + optional name), mono/stereo mode, selection (mono; stereo left/right), permission UI state, and small error/message states; no Apple I/O or persistence logic is inside models.

- [x] **T2 — Implement pure selection/formatting logic** (`Session Recorder/Features/AudioDevicesList/AudioDeviceSelectionHelper.swift`)
  - **RF:** RF-1, RF-2, RF-3, RF-5
  - **Depends on:** T1
  - **Done when:** Pure functions (explicit inputs, deterministic outputs) cover duplicate-name disambiguation (`A (1)`, `A (2)`), channel label formatting (`number` / `number (name)` / same-name rule), initial defaults, mono validation, stereo validation (2 different channels, left/right), incomplete-stereo no-save decision, tab-switch replacement, restore validity, invalid-selection (error, no default), and disconnect decision.

- [x] **T3 — Add local selection persistence** (`Session Recorder/Features/AudioDevicesList/AudioDeviceSelectionRepository.swift`)
  - **RF:** RF-3, NFR-5
  - **Depends on:** T1
  - **Done when:** Repository reads/writes per-device selections locally using **device/channel IDs only** (no personal data), saves immediately on valid mono or valid stereo-pair updates, and exposes records needed for restore; no UI code.

- [x] **T4 — Implement audio input device/permission service** (`Session Recorder/Features/AudioDevicesList/AudioInputDeviceService.swift`)
  - **RF:** RF-1, RF-2, RF-4, NFR-4
  - **Depends on:** T1
  - **Done when:** Apple-API service can list eligible input devices (built-in/external), observe connect/disconnect, provide channels in consistent order for a selected device, request/check audio-input permission on device selection, and report permission-state changes for automatic UI updates.

- [x] **T5 — Add view model/state coordination** (`Session Recorder/Features/AudioDevicesList/ViewModels/AudioSourceSelectionViewModel.swift`)
  - **RF:** RF-1, RF-2, RF-3, RF-4, RF-5, RF-6, C4
  - **Depends on:** T1, T2, T3, T4
  - **Done when:** View model coordinates service + logic + repository; selection is active only when a device is selected; permission-not-granted state hides channels and exposes retry; disconnect clears selection and sets a small error; invalid selection sets a small “no valid channel” error with no default; tab changes replace saved selection; restore applies last valid choice when device identity/channels are reliable.

- [x] **T6 — Build the audio source selection UI** (`Session Recorder/Features/AudioDevicesList/Views/AudioSourceSelectionView.swift`, `DeviceListView.swift`, `ChannelSelectionView.swift`)
  - **RF:** RF-1, RF-2, RF-3, RF-4, RF-5, NFR-1, NFR-3
  - **Depends on:** T1, T5
  - **Done when:** SwiftUI views render device list (disambiguated names, empty state), channel area (formatted channels, no-channels message), Mono/Stereo tabs, stereo left/right picks (no duplicates, save after valid pair), permission message + retry button (channels hidden when not granted), and small error messages for disconnect/no-valid-channel; views emit intents and contain no device/persistence business logic.

- [x] **T7 — Integrate UI above record button** (`Session Recorder/ContentView.swift`)
  - **RF:** RF-6
  - **Depends on:** T6
  - **Done when:** `ContentView` shows the audio source selection UI above the existing `RecordButton`, and the record control remains visible with platform-appropriate layout.

- [x] **T8 — Add SwiftUI previews for key states** (`Session Recorder/Features/AudioDevicesList/Views/AudioSourceSelectionView.swift` or preview support files as needed)
  - **RF:** RF-1, RF-2, RF-3, RF-4, RF-5, RF-6, C5
  - **Depends on:** T6
  - **Done when:** `#Preview` coverage exists for representative states: empty device list, duplicate names, no channels, permission not granted + retry, mono-only device, stereo left/right selection, disconnect/error, and restored selection.

- [x] **T9 — Manual/build verification pass**
  - **RF:** RF-1, RF-2, RF-3, RF-4, RF-5, RF-6, NFR-1, NFR-4, NFR-5, C5
  - **Depends on:** T7, T8
  - **Done when:** Project builds with `xcodebuild` for `Session Recorder` (macOS and/or iOS Simulator per `AGENTS.md`), and manual checks confirm: auto device/permission updates, channel formatting/disambiguation, mono/stereo rules and save timing, immediate persistence/restore behavior, permission retry flow, and disconnect/invalid-selection messages (no default applied). All new user-facing text is English.

- [x] **T10 — Optional native logic tests (only if valuable)** (Xcode test target + tests for `AudioDeviceSelectionHelper`)
  - **RF:** RF-1, RF-2, RF-3, RF-5, C5
  - **Depends on:** T2; create only if a native test target is justified
  - **Done when:** If added, native Xcode tests (no third-party frameworks) verify pure-logic cases with explicit inputs (disambiguation, formatting, defaults, mono/stereo validation, left/right, no-save incomplete stereo, tab replacement, restore/invalid/disconnect decisions); if not added, decision is documented as unnecessary for this scope.
  - **Decision (2026-11-09):** Not added. `AudioDeviceSelectionHelper` is pure/deterministic and suitable for native XCTest, but this repo has no test target and adding one requires `project.pbxproj` target/scheme changes (C6-sensitive). For this scope, behavior was verified via `xcodebuild` builds (macOS/iOS Simulator), SwiftUI previews, and manual runtime checks; add a native test target later if logic complexity/regression risk increases. No `node`/third-party test frameworks (C1/C5).

## Change: automatic device selection (RF-7, updated RF-5) — added 2026-11-11

- [ ] **T11 — Mark devices as external or built-in** (`AudioDeviceModels.swift`, `AudioInputDeviceService.swift`)
  - **RF:** RF-7
  - **Depends on:** none
  - **Done when:** `AudioInputDevice` exposes whether it is external; the service sets it from the discovered device type on macOS and iOS; the service offers a permission check that never shows the system prompt.

- [ ] **T12 — Persist last selected device ID** (`AudioDeviceSelectionRepository.swift`)
  - **RF:** RF-7, NFR-5
  - **Depends on:** none
  - **Done when:** The repository saves/loads one last-selected device ID (ID only) under a new key; existing per-device channel records are unchanged.

- [ ] **T13 — Pure automatic-selection decisions** (`AudioDeviceSelectionHelper.swift`)
  - **RF:** RF-7
  - **Depends on:** T11
  - **Done when:** Pure functions cover launch selection (last used → first external → built-in), selection on connect (only replaces built-in/none), fallback on disconnect (first external → built-in → none), and reselection on reconnect (only if the user did not change the source).

- [ ] **T14 — Apply automatic selection in the view model** (`ViewModels/AudioSourceSelectionViewModel+DeviceSelection.swift`, `AudioDeviceModels.swift`)
  - **RF:** RF-5, RF-7, RF-4
  - **Depends on:** T11, T12, T13
  - **Done when:** A device is auto-selected on start; connect/disconnect/reconnect follow RF-7; manual selection is respected and saved as last device; disconnect no longer deletes saved channel selection; automatic changes show a small message naming the new device; automatic selection never shows the system permission prompt.

- [ ] **T15 — Previews and verification** (`Views/AudioSourceSelectionView+Previews.swift`)
  - **RF:** RF-5, RF-7, C5
  - **Depends on:** T14
  - **Done when:** Previews show an auto-selected external device and a fallback-to-built-in state; `xcodebuild` succeeds for macOS and iOS Simulator; manual checks confirm launch order, connect, unplug/replug restore, and manual choice respected.

## Change: app structure, source row and source sheet (RF-6 updated) — added 2026-11-11

- [x] **T16 — Share one view model between Record tab, row and sheet** (`Views/AudioSourceSelectionView.swift`, `ContentView.swift`)
  - **RF:** RF-6, C4
  - **Depends on:** none
  - **Done when:** `AudioSourceSelectionView` reads the view model with `@EnvironmentObject` instead of creating it; `ContentView` creates it once (`@StateObject`, optional injection for previews) and injects it at the root with `.environmentObject`; previews inject it and compile.

- [x] **T17 — Add Record/Sessions tabs** (`ContentView.swift`)
  - **RF:** RF-6, NFR-1
  - **Depends on:** T16
  - **Done when:** The app shows Record and Sessions tabs (bottom bar on iPhone, sidebar-adaptive on iPad/Mac); Sessions shows a "No sessions yet" empty state; Record tab has a navigation title.

- [x] **T18 — Source summary in the view model** (`ViewModels/AudioSourceSelectionViewModel*.swift`)
  - **RF:** RF-6
  - **Depends on:** none
  - **Done when:** The view model exposes a summary for the row: device label, mode, channel numbers, or a state (no input, permission required, no valid channel); no new selection behavior.

- [x] **T19 — Source row on the Record tab** (`Views/AudioSourceSummaryRow.swift` — new file, ask before creating; `ContentView.swift`)
  - **RF:** RF-6
  - **Depends on:** T16, T17, T18
  - **Done when:** The Record tab shows the source row at the top, a message area below it (RF-5/RF-7 messages), and `RecordButton` pinned at the bottom and always visible; tapping the row opens the source sheet.
  - **Note (2026-11-11):** The sheet already has a minimal container (navigation title "Audio Source", **Done** button, scroll) so it can be dismissed on Mac; T20 turns its content into a native form. Record-tab messages show only what the row does not (currently: device disconnected).

- [x] **T20 — Turn the selection UI into the source sheet** (`Views/AudioSourceSelectionView.swift`, `Views/DeviceListView.swift`, `Views/ChannelSelectionView.swift`)
  - **RF:** RF-1–RF-6
  - **Depends on:** T19
  - **Done when:** The sheet uses a native `Form`/`List` with **Device** and **Channels** sections, title "Audio Source" and a **Done** button; it scrolls with many channels; changes apply immediately and update the row; messages appear in the sheet; works on iPhone, iPad and Mac.

- [x] **T21 — Previews and verification for the new layout** (`Views/AudioSourceSelectionView+Previews.swift`)
  - **RF:** RF-6, C5
  - **Depends on:** T20
  - **Done when:** Previews cover the Record tab, row states (selected mono/stereo, no input, permission required, no valid channel) and the sheet; `xcodebuild` succeeds for macOS and iOS Simulator; manual check on iPhone-size simulator confirms the record button stays visible with a many-channel device.
