# Tasks: First Use and Audio-Input Permission

Source: `specs/first-use/spec.md`, `specs/first-use/plan.md`.
Constraints: C1–C6 (SwiftUI/Apple APIs only, no deps, logic separated from UI, no personal data in persistence, English text). Keep tasks small (20–30 min), in dependency order. Paths are relative to `Session Recorder/`.

## Tasks

- [x] **T1 — Access logic and first-use flag** (`Features/FirstUse/AudioAccessLogic.swift`, `Features/FirstUse/FirstUseSettingsRepository.swift`)
  - **RF:** RF-1, RF-3, RF-6, NFR-3
  - **Depends on:** none
  - **Done when:** Pure functions cover access state, show-explanation, notice action and USB-C note rules (checked with a scratch script); the `first_use_explained_v1` flag can be read and set.

- [x] **T2 — Permission requests only on user action** (`AudioInputDeviceService.swift`, `AudioSourceSelectionViewModel+DeviceSelection.swift`)
  - **RF:** RF-2, RF-4, NFR-2
  - **Depends on:** none
  - **Done when:** Selecting a device no longer shows the system prompt; `requestAccess()` asks and, when granted, re-applies the automatic selection (meters appear without restart); the Mac refreshes the permission when the app becomes active.

- [x] **T3 — Settings link** (`Features/FirstUse/SystemSettingsLink.swift`)
  - **RF:** RF-3, NFR-5
  - **Depends on:** none
  - **Done when:** iPhone/iPad open the app's settings page; Mac opens System Settings › Privacy & Security › Microphone.

- [x] **T4 — First-use view model and explanation screen** (`Features/FirstUse/ViewModels/FirstUseViewModel.swift`, `Features/FirstUse/Views/FirstUseExplanationView.swift`, `ContentView.swift`)
  - **RF:** RF-1, RF-2, RF-5
  - **Depends on:** T1, T2
  - **Done when:** On first launch (permission undecided) the explanation appears (full screen on iPhone, sheet on iPad/Mac); Continue asks and closes; Not Now closes without asking; it does not appear again; the Sessions tab works after Not Now.

- [x] **T5 — Access notice on the Record tab and in the source sheet** (`Features/FirstUse/Views/AudioAccessNoticeView.swift`, `ContentView.swift`, `ChannelSelectionView.swift`)
  - **RF:** RF-3, RF-4
  - **Depends on:** T3, T4
  - **Done when:** Not asked → Allow Audio Input; denied → Open Settings; restricted → no button; shown instead of the meters and in the source sheet (no Try Again); returning from Settings with access allowed updates the app.

- [x] **T6 — USB-C note** (`ContentView.swift`)
  - **RF:** RF-6
  - **Depends on:** T1
  - **Done when:** The note shows with the built-in microphone and no external device, hides when a mixer is connected or while recording.

- [ ] **T7 — Previews** (`Features/FirstUse/Views/FirstUseViews+Previews.swift`)
  - **RF:** C5
  - **Depends on:** T4–T6
  - **Done when:** Previews exist for the explanation, each notice state and the USB-C note.

- [ ] **T8 — Docs** (`specs/audio-devices-list/spec.md`, `AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2
  - **Depends on:** T7
  - **Done when:** audio-devices-list RF-4/NFR-2 reflect the new flow; docs list `Features/FirstUse/` and the updated status.

- [ ] **T9 — Verification pass**
  - **RF:** RF-1–RF-6, NFR-1–NFR-5
  - **Depends on:** T1–T8
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; on a real iPhone and Mac (permission reset): Continue → allow, Continue → deny → Open Settings → allow → return, Not Now → Allow Audio Input, restricted text if available, USB-C note with/without the mixer.
