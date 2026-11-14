# Plan: First Use and Audio-Input Permission

## References
- `docs/constitution.md` (C1–C6)
- `specs/first-use/spec.md` (RF-1–RF-6, NFR-1–NFR-5, Decisions)
- `specs/audio-devices-list/spec.md` (RF-4 permission, RF-6 source row, RF-7 automatic selection, NFR-2)
- `specs/recording/spec.md` (RF-2 meters, RF-3 record button, RF-8 recovery)

## 1) Files to create or modify (responsibility + RF coverage)
New feature folder: `Session Recorder/Features/FirstUse/` (same pattern as the other features).

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Features/FirstUse/AudioAccessLogic.swift` | Create | **Pure logic**: access state from the permission state (`notAsked` / `denied` / `restricted` / `allowed`); whether the explanation shows (not asked + not yet explained); whether the USB-C note shows (allowed, built-in mic selected, no external device listed, no recording). | RF-1, RF-3, RF-6 |
| `Features/FirstUse/FirstUseSettingsRepository.swift` | Create | `UserDefaults` flag `first_use_explained_v1` (approved). | RF-1, NFR-3 |
| `Features/FirstUse/SystemSettingsLink.swift` | Create | Apple-API boundary: open the app's settings (iOS, `UIApplication.openSettingsURLString`) or System Settings › Privacy & Security › Microphone (Mac, `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`). | RF-3, NFR-5 |
| `Features/FirstUse/ViewModels/FirstUseViewModel.swift` | Create | Shows/hides the explanation, Continue (asks via the audio source), Not Now, Allow Audio Input, Open Settings; exposes the access state for notices. | RF-1–RF-3 |
| `Features/FirstUse/Views/FirstUseExplanationView.swift` | Create | One screen: icon, "Record your sessions", two or three short lines, Continue / Not Now. | RF-1, NFR-1 |
| `Features/FirstUse/Views/AudioAccessNoticeView.swift` | Create | Notice for not asked / denied / restricted with Allow Audio Input / Open Settings / no button; used on the Record tab and in the source sheet. | RF-3 |
| `Features/FirstUse/Views/FirstUseViews+Previews.swift` | Create | Previews: explanation, each notice, USB-C note. | C5 |
| `Features/AudioDevicesList/AudioInputDeviceService.swift` | Modify | `requestPermission()` (renamed from the device-selection request); refresh permission when the Mac app becomes active (iOS already refreshes on didBecomeActive). | RF-2, RF-4 |
| `Features/AudioDevicesList/ViewModels/AudioSourceSelectionViewModel+DeviceSelection.swift` | Modify | Selecting a device no longer shows the system prompt (spec NFR-2); `requestAccess()` replaces `retryPermission()`; after access is granted the automatic selection runs again. | RF-2, RF-3, RF-4 |
| `Features/AudioDevicesList/Views/ChannelSelectionView.swift` | Modify | Shows `AudioAccessNoticeView` instead of the message + Try Again. | RF-3 |
| `ContentView.swift` | Modify | Own `FirstUseViewModel`; present the explanation (`fullScreenCover` on iPhone, sheet on iPad/Mac); Record tab shows the access notice instead of meters, and the USB-C note under the source row. | RF-1, RF-3, RF-5, RF-6 |
| `specs/audio-devices-list/spec.md` | Modify | RF-4: retry replaced by the first-use notice; NFR-2 wording (asking only from Continue / Allow Audio Input). | C2 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `Session Recorder/MEMORY.md` | Modify | Feature folder, status. | C2 |

## 2) Pure/testable logic (`AudioAccessLogic`)
| Logic | Inputs | Output | RF |
|---|---|---|---|
| Access state | permission state | `.allowed` (granted), `.notAsked` (unknown), `.denied`, `.restricted` | RF-3 |
| Show explanation | access state, explained flag | `notAsked && !explained` | RF-1 |
| Notice action | access state | Allow Audio Input (notAsked) / Open Settings (denied) / none (restricted, allowed) | RF-3 |
| Show USB-C note | access state, selected device (`isExternal`), any external device listed, recording exists | allowed && selected is built-in && no external listed && no recording | RF-6 |

## 3) Technical design
### Flow
```text
launch ── permission unknown and not explained ──▶ explanation
   Continue ──▶ set explained ──▶ system prompt ──▶ granted: auto-select + meters
                                               └──▶ denied: denied notice
   Not Now  ──▶ set explained ──▶ not-asked notice (Allow Audio Input → system prompt)
launch ── permission denied/restricted ──▶ notice on Record tab and in the source sheet
return to app (iOS didBecomeActive, Mac NSApplication.didBecomeActive) ──▶ refresh permission ──▶ UI updates
```
- **Asking:** `AVCaptureDevice.requestAccess(for: .audio)` as today (iOS and Mac). It shows the system prompt only while the status is undetermined; for denied/restricted the notice is shown instead.
- **After granting:** the audio source view model re-applies the automatic selection (audio-devices-list RF-7), so meters appear without a restart.
- **Mac permission refresh:** macOS posts no permission-change notification; the service refreshes when the app becomes active (returning from System Settings).
- **iOS:** turning access off in Settings ends the app (system behavior); recording recovery already covers an interrupted recording (recording RF-8).

### Presentation
- iPhone: `fullScreenCover` (covers the app); iPad/Mac: `.sheet` (spec RF-1). Not dismissible by swipe (only Continue / Not Now).
- Record tab: when access is not allowed, `AudioAccessNoticeView` takes the meters' place; Record stays disabled (recording `canRecord` already requires a valid source with permission).
- Source sheet: the channel area shows the same notice (replaces the message + Try Again).
- USB-C note: one secondary line under the source row on the Record tab.

## 4) Texts (English, short)
| Place | Text |
|---|---|
| Explanation title | Record your sessions |
| Explanation body | Session Recorder uses audio input to show levels and record from your mixer, audio interface or microphone. Your recordings stay on this device. |
| Buttons | Continue · Not Now |
| Notice, not asked | Audio input is needed to show levels and record. · **Allow Audio Input** |
| Notice, denied | Audio input is turned off for Session Recorder. Turn it on in Settings to record. · **Open Settings** |
| Notice, restricted | Audio input is restricted on this device, so recording isn't available. |
| USB-C note | For the best quality, connect your mixer or audio interface over USB-C. |

## 5) Technical decisions and rejected alternatives
| Decision | Rejected alternative |
|---|---|
| Flag `first_use_explained_v1` in `UserDefaults` (approved). | Showing the explanation on every launch while undecided — repetitive after Not Now. |
| Selecting a device no longer asks for permission; only Continue / Allow Audio Input do. | Keeping the prompt on device selection — conflicts with the explanation-first flow (spec NFR-2). |
| Open Settings via system URLs. | Instructions only — more steps for the user. |
| Separate `Features/FirstUse/` folder. | Adding it to `AudioDevicesList` — mixes onboarding with device selection (C4). |

## 6) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Pure logic | Scratch script for `AudioAccessLogic`. | RF-1, RF-3, RF-6 |
| Build | `xcodebuild` macOS + iOS Simulator (scratch DerivedData). | NFR-1 |
| Previews | Explanation, notices, USB-C note. | C5 |
| Real devices | Reset permission (iOS: delete and reinstall the app; Mac: `tccutil reset Microphone <bundle id>`), then: Continue → allow; Continue → deny → Open Settings → allow → return; Not Now → Allow Audio Input; USB-C note with and without the mixer. | RF-1–RF-6 |
