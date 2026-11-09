# Spec: Audio Devices List and Channel Selection

## Context and Goal
Session Recorder (SwiftUI, Apple platforms) needs to let DJs/musicians choose a connected audio input source before recording from a mixer or external sound card. This version covers input-device discovery, channel visibility, and per-device mono/stereo channel selection (selection/persistence only; no actual recording).

## Users
- DJs/musicians using built-in inputs or external mixers/audio interfaces on supported Apple platforms.

## User Stories
- As a user, I want to see connected audio input devices so I can choose a recording source.
- As a user, I want to view a device’s input channels so I know what can be recorded.
- As a user, I want to select mono or stereo channels per device and have my last valid choice remembered.

## Functional Requirements

### RF-1: Input device list
- When the main feature view is presented, the system shall list connected devices that provide audio input (built-in and external).
- When an eligible device connects or disconnects, the system shall update the list automatically.
- When two devices share the same display name, the system shall distinguish them in the list (for example, `A (1)` and `A (2)`).
- If no eligible input devices are available, then the system shall show an empty state explaining that no audio input devices are available.

### RF-2: Channel display
- When the user selects a device and audio-input permission is granted, the system shall display its available input channels in a consistent order.
- When displaying a channel, the system shall show the channel number; if a device-provided name differs from that number, the system shall show it in parentheses; if it matches the number, the system shall show only the number.
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
- When no valid saved selection exists for a multi-channel device, the system shall use channel 1 as the initial mono choice and channels 1 and 2 as the initial stereo choice.

### RF-4: Audio-input permission
- When the user selects a device, the system shall attempt to obtain/use audio-input permission as needed for that source.
- If audio-input permission is not granted, then the system shall show a message in the channel/selection area stating that permission must be granted and shall provide a button to try granting permission again; the system shall not show device channels in that state.
- When audio-input permission status changes while the app/view is open, the system shall update the UI automatically.
- The system shall prevent recording-related use of the source until permission is granted.

### RF-5: Disconnection and invalid selection
- When a selected device disconnects or becomes unavailable, the system shall clear its selection and notify the user with a small error message.
- If the current or saved channel selection becomes invalid (no valid channel available), then the system shall show a small error message stating that no valid channel is available and shall not apply a default channel selection.

### RF-6: Placement
- When the main screen is shown, the system shall display the audio device list and channel selection UI above the record button, while keeping the existing record control visible.

## Non-Functional Requirements
- **NFR-1:** Behavior works across supported Apple platforms with platform-appropriate presentation.
- **NFR-2:** Permission requests occur in user-initiated device/source-selection context.
- **NFR-3:** Labels are clear for non-technical users and precise for multi-channel interfaces.
- **NFR-4:** Device, channel, and permission-state changes appear promptly/automatically.
- **NFR-5:** Persisted data contains no personal data (only device/channel IDs).

## Edge Cases
- Many-channel interfaces remain usable with consistent channel ordering.
- Duplicate device names are disambiguated in the list (RF-1).
- A device with no channels shows a no-channels message in the channel-list area (RF-2).
- A device/channel set becomes invalid: no default is applied; show a no-valid-channel error (RF-5).
- A stereo selection is incomplete until two different channels are chosen; no stereo save occurs before a valid pair.
- A disconnected device’s selection is cleared and the user is notified (RF-5).

## Out of Scope
- Actual audio recording, metering/waveform/monitoring, file export/naming/playback.
- MIDI listing/mapping/sync, advanced routing, channel grouping beyond 1 or 2 selected channels, sample-rate/format configuration.
- Output-only devices as record sources.

## Completion Criteria
- Input devices appear above the record button, update automatically, and disambiguate duplicate names.
- With permission granted, selecting a device shows channels with the specified formatting; without permission, a permission message and retry action are shown.
- Mono/Stereo tabs enforce selection rules (left/right for stereo, no duplicate channel, single-channel devices mono-only), save valid choices immediately, and restore the last valid choice on restart when device identity/channels are reliable.
- Disconnection and invalid-selection cases show small error messages and follow RF-5.
- All new user-facing text is in English.

## Open Questions
- None.
