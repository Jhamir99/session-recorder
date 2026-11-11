# Plan: Audio Devices List and Channel Selection

## References
- `docs/constitution.md` (C1–C6)
- `specs/audio-devices-list/spec.md` (RF-1–RF-7)

## 1) Files to create or modify (responsibility + RF coverage)
All new implementation files go in `Session Recorder/Features/AudioDevicesList/` (new folder; creating files/folder approved in spec workflow — keep minimal). Views are in `Session Recorder/Features/AudioDevicesList/Views/`.

| File | Action | Responsibility | RF |
|---|---|---|---|
| `Session Recorder/ContentView.swift` | Modify | Place the audio-source UI **above** the existing record button; keep record control visible. Compose state only (no device/persistence logic). | RF-6 |
| `Session Recorder/Features/AudioDevicesList/Views/AudioSourceSelectionView.swift` | Create | SwiftUI UI: device list, duplicate-name labels, selected-device area, permission message + retry button, no-channels/no-valid-channel small error messages, Mono/Stereo tabs, channel rows/selection. Renders state and emits user intents. | RF-1, RF-2, RF-3, RF-4, RF-5, RF-6 |
| `Session Recorder/Features/AudioDevicesList/Views/DeviceListView.swift` | Create | Device list subview (disambiguated names, empty state), receives view model via environment. | RF-1 |
| `Session Recorder/Features/AudioDevicesList/Views/ChannelSelectionView.swift` | Create | Channel/permission/mode/selection subview (Mono/Stereo tabs, Left/Right stereo columns), receives view model via environment. | RF-2, RF-3, RF-4, RF-5 |
| `Session Recorder/Features/AudioDevicesList/AudioDeviceModels.swift` | Create | Value types for device identity/display name, channel (number + optional name), mode (mono/stereo), selection (mono / stereo left+right), permission UI state, and user-facing message states. No Apple-device I/O. | RF-1–RF-5 |
| `Session Recorder/Features/AudioDevicesList/AudioDeviceSelectionHelper.swift` | Create | **Pure/testable logic**: disambiguate device names, format channel labels, defaults, stereo validation (2 different channels, left/right), no-valid-channel handling, restore validation, tab-switch replacement. | RF-1, RF-2, RF-3, RF-5 |
| `Session Recorder/Features/AudioDevicesList/AudioDeviceSelectionRepository.swift` | Create | Local persistence of per-device selection (**device/channel IDs only, no personal data**). Save immediately on valid selection; load records for restore. | RF-3, NFR-5 |
| `Session Recorder/Features/AudioDevicesList/AudioInputDeviceService.swift` | Create | Apple-API boundary: discover eligible input devices, observe connect/disconnect, expose channels, request/check audio-input permission, report permission changes. Publishes normalized model data. | RF-1, RF-2, RF-4, NFR-4 |
| `Session Recorder/Features/AudioDevicesList/ViewModels/AudioSourceSelectionViewModel.swift` (+ `+DeviceSelection`, `+ChannelSelection`, `+Preview` extensions) | Create | Coordinates service + pure logic + repository; holds UI state; enforces permission-gated channel view, retry, selection active only when device selected, clear+notify on disconnect, no default on invalid selection. | RF-1–RF-6, C4 |
| `Session Recorder/CONSTANTS.swift` | Modify only if needed | Add small shared English text constants only if duplication is harmful. | RF-1–RF-5, C6 |
| `specs/audio-devices-list/spec.md` | No change unless behavior changes | Source of truth; update only if approved scope changes. | C2 |

## 2) Pure/testable logic (explicit inputs; no `"hoy"`/no I/O)
The equivalent of “today as a parameter”: pass explicit inputs (devices, channels, IDs, saved records, permission/mode/candidate picks) and return deterministic results.

| Logic | Inputs (explicit) | Output | RF |
|---|---|---|---|
| Disambiguate device names | ordered `(id, displayName)` | labels with duplicate suffixes (`A (1)`, `A (2)`) | RF-1 |
| Format channel label | `(channelNumber, optionalName)` | `number` or `number (name)` per spec | RF-2 |
| Channel-area state | permission, channels | permission message+retry / no-channels / channel list | RF-2, RF-4 |
| Initial defaults | available channel IDs (consistent order) | mono `[1st]`, stereo `[1st,2nd]` when available | RF-3 |
| Mono validation | candidate, available channels | valid; single-channel => mono only | RF-3 |
| Stereo validation | left, right, available channels | valid only if both present, different; order = left,right | RF-3 |
| Save decision | mode, candidate(s), validity | save immediately for valid mono or valid pair; never incomplete stereo | RF-3 |
| Tab-switch replacement | device ID, mode, latest valid choice | replacement saved selection for device | RF-3 |
| Restore decision | saved record, reliably identified device, current channels | restore last valid choice or no restore | RF-3 |
| Invalid-selection decision | current/saved selection vs channels | small “no valid channel” error; **no** default applied | RF-5 |
| Disconnect decision | selected device ID, current devices | clear selection + small disconnected error | RF-5 |
| Permission UI decision | permission status | hide channels + retry when not granted; auto-update on changes | RF-4 |

## 3) Algorithm pseudocode
```text
Covers RF-1–RF-5 (logic/state; UI rendering separate)

on appear:
  observe input devices + permission (service)
  load persisted selections, IDs only (store)
  render device UI above record button

on devices update(devices):
  labels = disambiguate(devices)
  if selected missing: clear selection; notify disconnected
  if no eligible devices: show empty state

on select device(device):            // active only when selected
  selected = device
  request/check permission
  if not granted: show permission message + retry; hide channels
  else if device.channels empty: show "no channels available"
  else restoreOrInitialize(device, channels)

restoreOrInitialize(device, channels):
  saved = store.get(reliablyIdentified device)
  if saved valid in channels: restore last choice
  else set initial mono=first, stereo=first+second when available

on tab switch(mode): replace device saved selection with latest valid choice for mode

on mono pick(ch): if valid -> set + save immediately
on stereo pick(ch):
  first pick -> hold left (no save)
  second pick -> if valid pair and different -> set left,right + save immediately

on permission/devices/channels change:
  refresh UI automatically
  if selection invalid: clear; show "no valid channel available"; no default
```

## 4) UI rendering
| UI area | Behavior | RF |
|---|---|---|
| Main screen | `ContentView` renders audio-source UI above `RecordButton`; record control remains. | RF-6 |
| Device list | Eligible inputs with disambiguated names; empty state when none; tap selects device. | RF-1 |
| Permission not granted | Message + “try granting permission again” button in channel/selection area; channels hidden. Auto-updates. | RF-4 |
| Channels (granted) | No-channels message or ordered channel rows (`number` / `number (name)`) with **Mono/Stereo** tabs. | RF-2, RF-3 |
| Selection | Mono: 1 channel. Stereo: 2 different channels, left then right. Single-channel: mono only. Tab switch replaces saved selection. | RF-3 |
| Errors | Small messages for disconnected device and no valid channel available. | RF-5 |
| Platforms | Platform-appropriate presentation, same behavior across supported Apple targets. | NFR-1, NFR-3 |

## 5) Technical decisions and rejected alternatives
| Decision | Justification | Rejected alternative | RF |
|---|---|---|---|
| Apple APIs only (AVFoundation/CoreAudio as appropriate) | C1, C6. | Third-party audio libs — violates C1/C6. | RF-1,2,4 |
| Service + pure logic + view model + views in `Features/AudioDevicesList/` | C4; testable rules; Views render intent/state only. | Logic/persistence in Views — violates C4. | RF-1–6 |
| Persist **device/channel IDs only**, immediate save on valid choice | RF-3, NFR-5, approved C6 exception. | Personal data/broad config; save incomplete stereo. | RF-3, NFR-5 |
| Restore only for reliably identified same physical device with valid channels | Avoid wrong restore. | Name-based best-effort restore. | RF-3 |
| Invalid selection => error, **no default** | Matches spec. | Silent fallback default. | RF-5 |
| Permission not granted => message+retry, hide channels | Matches spec. | Show disabled channels. | RF-4 |

## 6) Test strategy (C5; no `node --test`, no deps)
| Strategy | How | RF |
|---|---|---|
| Pure-logic verification | Add a native Xcode test target **only if valuable**; test `AudioDeviceSelectionHelper` with explicit inputs. No third-party test frameworks. | RF-1–5 |
| Build verification | `xcodebuild -project "Session Recorder.xcodeproj" -scheme "Session Recorder" -configuration Debug -destination 'platform=macOS' build` (and iOS Simulator destination per `AGENTS.md`). | NFR-1, RF-6 |
| SwiftUI previews | `#Preview` states: empty, duplicates, no channels, permission denied+retry, mono-only, stereo L/R, disconnect/error, restored selection. | RF-1–6 |
| Manual integration | Real/simulated connect/disconnect, permission grant/revoke while open, restart restore for same interface. | RF-1,3,4,5, NFR-4 |

## 7) RF coverage summary
- **RF-1:** list/auto-update/duplicate disambiguation/empty — (1)-(4),(6).
- **RF-2:** channel format/order, no-channels, permission-gated display — (1)-(4),(6).
- **RF-3:** Mono/Stereo tabs, 1 or 2 different channels, left/right, save timing/immediate, tab replacement, active only when selected, restore last valid, defaults/single-channel — (1)-(6).
- **RF-4:** prompt on device select, message+retry, hide channels, auto permission updates, block recording-related use — (1)-(4),(6).
- **RF-5:** disconnect clear+notify; invalid selection error with no default — (1)-(4),(6).
- **RF-6:** above record button, record control remains — (1),(4),(6).
- **RF-6 (updated 2026-11-11):** tabs, source row, source sheet — (9).
- **RF-7:** automatic device selection (launch order, connect, disconnect fallback, reconnect restore, manual choice respected) — (8).

## 8) Change: automatic device selection (RF-7, updated RF-5)

### Files to modify
| File | Change | RF |
|---|---|---|
| `AudioDeviceModels.swift` | Add whether a device is external or built-in to `AudioInputDevice`; add a message kind for automatic source changes. | RF-7 |
| `AudioInputDeviceService.swift` | Set the external flag: on macOS from the Core Audio transport type (wired only: USB, Thunderbolt, FireWire, PCI, AVB; USB interfaces are reported as `.microphone`, so device type is not enough); on iOS from device type `.external`. Use the existing `refreshPermissionState()` as the permission *check* without prompting. | RF-7, RF-4 |
| `AudioDeviceSelectionHelper.swift` | Pure decisions: launch selection, selection on connect, fallback on disconnect, reselection on reconnect. | RF-7 |
| `AudioDeviceSelectionRepository.swift` | Save/load the last selected device ID (new key; device ID only). | RF-7, NFR-5 |
| `ViewModels/AudioSourceSelectionViewModel+DeviceSelection.swift` | Apply automatic selection on start and on device-list changes; track "replaced device" and whether the user changed the source manually; stop deleting saved channel selection on disconnect; set the automatic-change message. | RF-5, RF-7 |
| `Views/AudioSourceSelectionView+Previews.swift` | Previews for auto-selected external, fallback to built-in after disconnect. | RF-7 |

### Pure logic (explicit inputs)
| Logic | Inputs | Output |
|---|---|---|
| Launch selection | devices (with external flag, list order), last selected device ID | device ID or none |
| Selection on connect | previous device IDs, current devices, current selected ID | new device ID or keep current |
| Fallback on disconnect | current devices, disconnected device ID | external (first) → built-in → none |
| Reselection on reconnect | replaced device ID, user changed source manually, current devices | replaced device ID or keep current |

### Pseudocode
```text
on start:
  id = launchSelection(devices, store.lastSelectedDeviceID)
  if id: autoSelect(id)

on devices update(old, new):
  if selected device missing:
    replacedDeviceID = selected; userChangedSource = false
    id = fallback(new, selected)            // keep its saved channels
    if id: autoSelect(id, message: "Switched to <name>") else empty state
  else if replacedDeviceID in new and !userChangedSource:
    autoSelect(replacedDeviceID, message); replacedDeviceID = nil
  else if newly connected external and (selected is built-in or none):
    autoSelect(external, message)

autoSelect(id):  // no permission prompt (check only)
  selected = id; store.lastSelectedDeviceID = id
  if permission granted: restoreOrInitialize else permission message + retry

on manual select(id):
  userChangedSource = true; replacedDeviceID = nil
  store.lastSelectedDeviceID = id; existing flow (may prompt permission)
```

### Decisions
| Decision | Rejected alternative |
|---|---|
| Persist last selected device ID (approved 2026-11-11; ID only). | Not persisting it — launch would ignore the user's last choice. |
| Keep saved channel selection on disconnect. | Delete it (previous behavior) — reconnect would lose channels. |
| Automatic selection never shows the system permission prompt (NFR-2). | Prompt on launch without user context. |
| Recording lock is a hook for the future recording feature. | Implementing recording state now (out of scope). |
| Only wired devices count as external (2026-11-11), so connecting AirPods or a virtual/Continuity input never switches the source. | Any non-built-in device — Bluetooth headsets would take over the source. |

## 9) Change: app structure, source row and source sheet (RF-6 updated)

### Current state (before change)
- `MyApp` shows `ContentView` directly: no tabs, no navigation container.
- `ContentView` stacks `AudioSourceSelectionView` and `RecordButton` in a `VStack` with no scrolling; long channel lists push the record button off screen on iPhone.
- `AudioSourceSelectionView` owns its view model (`@StateObject`), so a separate row and sheet cannot share state.
- Device and channel rows are plain buttons in `VStack`s; messages are red text inside the list.

### Files to modify / create
| File | Change | RF |
|---|---|---|
| `Session Recorder/ContentView.swift` | Becomes the app shell: `TabView` with Record and Sessions tabs (platform-adaptive, sidebar on iPad/Mac). Record tab: navigation container, source row at top, message area, `RecordButton` pinned at the bottom. Sessions tab: empty state. Owns the `AudioSourceSelectionViewModel` (one instance shared by row and sheet). | RF-6 |
| `Views/AudioSourceSummaryRow.swift` | **New file (approval required before creating).** Compact row: device name + mode + channels, or state text (no input / permission required / no valid channel). Tap opens the sheet. | RF-6 |
| `Views/AudioSourceSelectionView.swift` | Becomes the sheet content: reads the shared view model from the environment instead of creating it; `Form`/`List` with sections **Device** and **Channels**; title "Audio Source"; **Done** button; scrolls. | RF-1–RF-6 |
| `Views/DeviceListView.swift`, `Views/ChannelSelectionView.swift` | Render rows as native list/form rows (checkmarks, segmented Mono/Stereo) inside the sheet sections. Behavior unchanged. | RF-1–RF-4 |
| `AudioSourceSelectionViewModel` (+ extension) | Expose a source summary for the row (device label, mode, channel numbers, state). No behavior changes. | RF-6 |
| `Views/AudioSourceSelectionView+Previews.swift` | Update previews for sheet content; add previews for the row states and the Record tab. | RF-6, C5 |

### Decisions
| Decision | Rejected alternative |
|---|---|
| Keep tabs in `ContentView` and the Sessions empty state inline (no new shell files). | New `AppShell` feature folder now — speculative until the library exists (C1). |
| View model owned by `ContentView` (`@StateObject`) and injected with `.environmentObject` at the root; views read it with `@EnvironmentObject` (same pattern as `DeviceListView`/`ChannelSelectionView`). | Two view models — would duplicate device observation and selection state. Passing it as a parameter — more boilerplate across row/sheet/subviews. |
| Reuse `AudioSourceSelectionView` as sheet content. | New sheet view duplicating device/channel UI. |
| Messages shown on the Record tab and in the sheet. | Only in the sheet — users would miss automatic changes. |
| Quality picker and level meters not added here. | Placeholders now — belong to the recording feature spec. |
