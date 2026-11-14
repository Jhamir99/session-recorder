# Spec: Audio Devices List and Channel Selection

## Context and Goal
Session Recorder (SwiftUI, Apple platforms) needs to let DJs/musicians choose a connected audio input source before recording from a mixer or external sound card. This version covers input-device discovery, channel visibility, and per-device mono/stereo channel selection (selection/persistence only; no actual recording).

## Users
- DJs/musicians using built-in inputs or external mixers/audio interfaces on supported Apple platforms.

## User Stories
- As a user, I want to see connected audio input devices so I can choose a recording source.
- As a user, I want to view a device’s input channels so I know what can be recorded.
- As a user, I want to select mono or stereo channels per device and have my last valid choice remembered.
- As a user, I want my USB-C mixer/interface to be selected automatically when I connect it, and the app to fall back to the built-in microphone when it is unplugged.

## Functional Requirements

### RF-1: Input device list
- When the main feature view is presented, the system shall list connected devices that provide audio input (built-in and external).
- When an eligible device connects or disconnects, the system shall update the list automatically.
- When two devices share the same display name, the system shall distinguish them in the list (for example, `A (1)` and `A (2)`).
- If no eligible input devices are available, then the system shall show an empty state explaining that no audio input devices are available.

### RF-2: Channel display
- When the user selects a device and audio-input permission is granted, the system shall display its available input channels in a consistent order.
- When displaying a channel, the system shall show only the channel number (device-provided channel names are not shown; changed 2026-11-12 because they repeated the device name).
- If a selected device has no available input channels, then the system shall show a message in the channel-list area stating that no channels are available.

### RF-3: Mono/stereo selection and persistence
- When viewing a selected device with permission granted, the system shall provide **Mono** and **Stereo** tabs.
- Where Mono is selected, the system shall allow selecting exactly 1 channel.
- Where Stereo is selected, the system shall allow selecting exactly 2 different channels; the first selected channel shall be treated as left and the second as right; the system shall not allow selecting the same channel twice.
- When a valid Mono or valid Stereo selection is made, the system shall save it immediately for that device locally (no personal data; device/channel IDs only). A Stereo selection shall be saved only after a valid pair is selected.
- When the user switches between Mono and Stereo tabs for a device, the system shall replace that device’s saved selection with the latest valid choice for the selected tab/mode.
- A device’s selection shall be considered active only when that device is selected by the user.
- When the app restarts and the same physical device/interface can be reliably identified with valid saved channels, the system shall restore that device’s last selected choice; if it cannot be reliably identified or channels are not valid, the system shall not restore it.
- When a device has only 1 available input channel, the system shall use mono with that channel and shall not allow a stereo pair.
- When no valid saved selection exists for a multi-channel device, the system shall select **Stereo** with channels 1 and 2 (left, right); channel 1 shall be the initial choice of the Mono tab (changed 2026-11-12; previously Mono was selected first).

### RF-4: Audio-input permission
- Selecting a device does not show the system permission prompt (changed 2026-11-14 by `specs/first-use/`): access is asked only from the first-use explanation (**Continue**) or **Allow Audio Input**.
- If audio-input permission is not granted, then the system shall show the first-use access notice in the channel/selection area (**Allow Audio Input** when not asked yet, **Open Settings** when denied, no button when restricted; first-use RF-3); the system shall not show device channels in that state.
- When audio-input permission status changes while the app/view is open, the system shall update the UI automatically.
- The system shall prevent recording-related use of the source until permission is granted.

### RF-5: Disconnection and invalid selection
- When a selected device disconnects or becomes unavailable, the system shall notify the user with a small message and select a fallback device as defined in RF-7.
- When a selected device disconnects, the system shall keep that device's saved channel selection so it can be restored if the device reconnects.
- If the current or saved channel selection becomes invalid (no valid channel available), then the system shall show a small error message stating that no valid channel is available and shall not apply a default channel selection.

### RF-6: App structure and placement
- The app shall have two tabs: **Record** and **Sessions**. On iPhone they appear as a bottom tab bar; on iPad and Mac they may appear as a sidebar (platform-adaptive).
- Until the session library feature exists, the Sessions tab shall show an empty state (for example, "No sessions yet").
- When the Record tab is shown, the system shall display a compact **source row** at the top and the record control at the bottom; the record control shall stay visible regardless of how many devices or channels exist.
- The source row shall show the selected device name and its channel selection (for example, `Xone:96 · Stereo · 1–2` or `iPhone Microphone · Mono · 1`). If no device is selected, permission is missing, or the selection is invalid, the row shall show that state instead (for example, "No input selected", "Permission required").
- When the user taps the source row, the system shall open a **source sheet** containing the device list (RF-1) and channel selection (RF-2, RF-3, RF-4), using native list/form presentation and scrolling when content does not fit. The sheet shall have a **Done** action to close it.
- Changes made in the source sheet shall apply immediately (no separate save step) and be reflected in the source row.
- Small messages from RF-5 and RF-7 (disconnected device, automatic source change, no valid channel) shall be visible on the Record tab near the source row, and also inside the sheet when it is open.

### RF-7: Automatic device selection
- When the app starts, the system shall select a device automatically, in this order: (1) the last selected device, if connected and reliably identified; (2) otherwise, a connected external device (the first in list order); (3) otherwise, the built-in input.
- When the selected device changes (manually or automatically), the system shall save its device ID locally as the last selected device (device ID only; no personal data).
- When an external device connects and the current source is the built-in input or no device is selected, the system shall select the newly connected external device. If another external device is already selected, the system shall keep the current selection.
- When the selected device disconnects, the system shall select a fallback: another connected external device if available (first in list order), otherwise the built-in input. If no eligible devices remain, the system shall show the empty state (RF-1).
- When a device that was replaced by a fallback reconnects and the user has not manually changed the source since then, the system shall select that device again and restore its saved channel selection (RF-3).
- When the user manually selects a device, the system shall keep that choice; automatic changes happen only on later connect/disconnect events as defined above.
- When a device is selected automatically, the system shall apply the same channel restore/default rules as a manual selection (RF-3).
- When a device is selected automatically and audio-input permission has not been granted, the system shall not show the system permission prompt; it shall show the access notice (RF-4).
- When the selection changes automatically because of a connect/disconnect, the system shall inform the user with a small message naming the newly selected device.
- While a recording is in progress (future recording feature), the system shall not change the selected device automatically.

## Non-Functional Requirements
- **NFR-1:** Behavior works across supported Apple platforms with platform-appropriate presentation.
- **NFR-2:** Permission requests occur only after a user action (first-use Continue / Allow Audio Input).
- **NFR-3:** Labels are clear for non-technical users and precise for multi-channel interfaces.
- **NFR-4:** Device, channel, and permission-state changes appear promptly/automatically.
- **NFR-5:** Persisted data contains no personal data (only device/channel IDs, including the last selected device ID).

## Edge Cases
- Many-channel interfaces remain usable with consistent channel ordering; the source sheet scrolls and the record control stays visible (RF-6).
- A device disconnects while the source sheet is open: the sheet updates and shows the message; the row reflects the fallback device (RF-6, RF-7).
- Duplicate device names are disambiguated in the list (RF-1).
- A device with no channels shows a no-channels message in the channel-list area (RF-2).
- A device/channel set becomes invalid: no default is applied; show a no-valid-channel error (RF-5).
- A stereo selection is incomplete until two different channels are chosen; no stereo save occurs before a valid pair.
- A disconnected device is replaced by a fallback device, the user is notified, and its saved channel selection is kept (RF-5, RF-7).
- Several external devices connected at launch with no last-used device: the first external in list order is selected (RF-7).
- The last used device is connected but the user previously chose the built-in input manually: the last selected device (built-in) is restored (RF-7).
- An external device is unplugged and plugged back in: it is selected again with its channel selection if the user did not change the source meanwhile (RF-7).

## Out of Scope
- Actual audio recording, metering/waveform/monitoring, file export/naming/playback.
- MIDI listing/mapping/sync, advanced routing, channel grouping beyond 1 or 2 selected channels, sample-rate/format configuration (quality will be added to the source row/sheet by the recording feature).
- Level meters, session library content, and recording controls beyond the existing record button.
- Output-only devices as record sources.

## Completion Criteria
- The app shows Record and Sessions tabs (sidebar on iPad/Mac where appropriate); Sessions shows an empty state.
- The Record tab shows the source row at the top and the record control at the bottom, always visible; tapping the row opens the source sheet with device list and channel selection; changes apply immediately and update the row (RF-6).
- Input devices appear in the source sheet, update automatically, and disambiguate duplicate names.
- With permission granted, selecting a device shows channels with the specified formatting; without permission, a permission message and retry action are shown.
- Mono/Stereo tabs enforce selection rules (left/right for stereo, no duplicate channel, single-channel devices mono-only), save valid choices immediately, and restore the last valid choice on restart when device identity/channels are reliable.
- Disconnection and invalid-selection cases show small error messages and follow RF-5.
- At launch a device is selected automatically (last used → external → built-in); connecting an external device replaces the built-in input but not another external; disconnecting falls back and notifies; reconnecting restores the previous device when the user has not changed the source; manual choices are respected (RF-7).
- All new user-facing text is in English.

## Open Questions
- None.
