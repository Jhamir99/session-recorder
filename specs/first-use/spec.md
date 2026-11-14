# Spec: First Use and Audio-Input Permission

## Context and Goal
Session Recorder needs access to audio input (the mixer/interface or the built-in microphone) to show level meters and record. Today the app never explains this: the system permission prompt appears only when the user selects a device in the source sheet (audio-devices-list RF-4), and when access is denied the sheet shows "Permission must be granted…" with a **Try Again** button that cannot help, because after a denial the system never shows the prompt again — access can only be turned on in Settings. This feature adds a short explanation before the system prompt on first use, a clear notice with **Open Settings** when access is denied, and a note suggesting a USB-C mixer/interface when only the built-in microphone is available (README "UI": First use, No external device).

## Users
- New users opening the app for the first time.
- Users who denied audio-input access (on purpose or by mistake) and now want to record.
- Users recording with the built-in microphone who may not know a mixer/interface can be connected.

## User Stories
- As a new user, I want to understand why the app needs audio input before the system asks me, so I can decide with confidence.
- As a user who denied access, I want the app to tell me how to turn it on and take me to the right place in Settings.
- As a user, I want to browse and play my saved sessions even if audio input is not allowed.
- As a user with only the built-in microphone, I want to know that I can connect my mixer over USB-C for better quality.

## Functional Requirements

### RF-1: First-use explanation
- When the app opens and audio-input access has not been decided yet (the system has never asked), the system shall show a short explanation screen before any system permission prompt.
- The screen shall explain, in plain English, that audio input is used to show input levels and record sessions from a mixer/interface or the built-in microphone, and that recordings stay on the device.
- The screen shall offer **Continue**, which shows the system permission prompt, and **Not Now**, which closes the screen without asking.
- After the system prompt has been answered, or after **Not Now**, the explanation shall not be shown again on its own (see Decisions).
- On iPhone the screen shall cover the app; on iPad and Mac it shall be presented as a sheet over the window.

### RF-2: After the permission answer
- When access is granted, the system shall continue as today: the automatically selected source is used and the level meters appear on the Record tab (recording RF-2, audio-devices-list RF-7).
- When access is denied, the system shall show the denied notice (RF-3) right away.

### RF-3: Access not allowed (denied, restricted, or not asked yet after Not Now)
- While audio input is not allowed, the Record tab shall show a notice in place of the level meters explaining why recording is unavailable, and the Record button shall stay disabled (recording RF-3).
- **Not asked yet** (the user chose Not Now): the notice shall offer **Allow Audio Input**, which shows the system prompt (the explanation is not shown again).
- **Denied:** the notice shall say that access was turned off and how to turn it on, and offer **Open Settings**, which opens the app's settings page on iPhone/iPad, or **System Settings › Privacy & Security › Microphone** on Mac.
- **Restricted** (for example, by Screen Time or device management): the notice shall explain that access is restricted on this device and shall not offer a button.
- The source sheet shall show the same state and action instead of the current "Try Again" button (replaces audio-devices-list RF-4's retry for the denied case).

### RF-4: Permission changes outside the app
- When the user returns to the app after changing audio-input access in Settings, the system shall update without a restart: when access is now granted, the notice disappears, the source is selected (audio-devices-list RF-7) and the meters appear.
- If the system ends the app because access was turned off while it was running (iOS does this), any recording in progress shall be recovered on next launch (recording RF-8).

### RF-5: Sessions without permission
- The Sessions tab (library) shall work normally without audio-input access: list, playback, rename, delete, trim and share do not need it.
- The first-use explanation shall not block the Sessions tab after **Not Now**.

### RF-6: No external device note
- When audio input is allowed, the selected source is the built-in microphone, and no external (USB) device is connected, the Record tab shall show a short note under the source row: "For the best quality, connect your mixer or audio interface over USB-C."
- The note shall disappear as soon as an external device is connected and selected (audio-devices-list RF-7), and shall not appear while a recording exists.
- The note shall not be shown on a Mac without a built-in microphone in use (for example, when another input device is selected).

## Non-Functional Requirements
- **NFR-1:** Works on iPhone, iPad and Mac with platform-appropriate presentation; texts readable at large Dynamic Type sizes; VoiceOver reads the explanation and buttons in order.
- **NFR-2:** The system permission prompt is only shown after a user action (Continue or Allow Audio Input), never automatically (keeps audio-devices-list NFR-2).
- **NFR-3:** No personal data is stored; any persisted flag only records whether the explanation was shown.
- **NFR-4:** User-facing text in English, short, and understandable to non-technical users.
- **NFR-5:** Only Apple APIs; opening Settings uses the system URLs for the app settings (iOS) and the Microphone privacy pane (Mac).

## Edge Cases
- First launch with a mixer already connected: explanation → Continue → granted → the mixer is selected and its meters appear (RF-1, RF-2).
- Not Now, then the user opens the source sheet: the sheet shows the not-asked state with **Allow Audio Input**, not the system prompt automatically (RF-3, NFR-2).
- Denied, then the user opens Settings, allows access and comes back: notice disappears, meters appear (RF-4).
- Access granted, then turned off in Settings while the app is in the background: iOS ends the app; on next launch the denied notice is shown (RF-3, RF-4).
- Restricted device: no Open Settings button (RF-3).
- App reinstalled (iOS resets the permission): the explanation is shown again (RF-1).
- A recording exists while the built-in microphone is in use: no USB note (RF-6).
- Mac with only an external interface and no built-in microphone: no USB note (RF-6).

## Out of Scope
- A multi-page onboarding or feature tour.
- Other permissions (notifications, files): not needed by the app.
- Changing how devices are selected automatically (audio-devices-list RF-7).

## Completion Criteria
- On a fresh install, the explanation appears before the system prompt; Continue shows the prompt; Not Now leaves the app usable with an Allow Audio Input action (RF-1, RF-3, RF-5).
- After granting, meters appear without restarting; after denying, the notice with Open Settings appears and opens the right place on iPhone/iPad and Mac (RF-2, RF-3).
- Returning from Settings with access granted updates the app without a restart (RF-4).
- The source sheet shows the same states; the old "Try Again" no longer appears after a denial (RF-3).
- The USB-C note appears only with the built-in microphone and no external device, and disappears when a mixer is connected (RF-6).
- Verified on a real iPhone and Mac, including deny → Settings → allow.

## Decisions (approved 2026-11-14)
- **Not Now** is offered. After Not Now the explanation does not appear again on its own; the user asks for access with **Allow Audio Input** (RF-3). A small persisted flag `first_use_explained_v1` records that the explanation was shown (NFR-3).
- **USB-C note (RF-6)** is part of this feature.
- **Explanation:** one screen with an icon, a title ("Record your sessions") and two or three short lines; no feature tour.

## Open Questions
- None.
