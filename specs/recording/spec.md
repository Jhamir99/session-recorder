# Spec: Recording

## Context and Goal
Session Recorder lets DJs/musicians record sessions from a USB-C mixer/interface (or the built-in microphone) on iPhone, iPad, and Mac. The `audio-devices-list` feature already selects the source device and its mono/stereo channels. This feature adds the actual recording: quality selection, always-on level meters, record/pause/resume/stop, live recording info (elapsed time, file size, remaining time), background recording, automatic save on stop, and handling of interruptions (disconnect, calls, low storage). The session library (list, playback, rename, delete, trim, share/export) is a separate feature.

## Users
- DJs/musicians recording practice or performance sessions from a mixer/interface or the built-in microphone.

## User Stories
- As a user, I want to see input levels before and during recording so I can set the gain on my mixer and avoid clipping.
- As a user, I want to record in lossless quality (up to 24-bit/48 kHz) and choose a lower quality if I want.
- As a user, I want to start, pause, resume, and stop a recording with large, clear controls.
- As a user, I want to see how long I have been recording, how big the file is, and how much recording time I have left.
- As a user, I want recording to continue when my iPhone is locked or the app is in the background.
- As a user, I want my session saved automatically when I stop, without having to name it.
- As a user, I want my recording to survive interruptions (cable unplugged, phone call, low storage) without losing what I already recorded.
- As a Mac user, I want keyboard shortcuts and a menu to control recording.

## Functional Requirements

### RF-1: Recording quality
- The system shall offer quality options made of a **sample rate** (44.1 kHz or 48 kHz) and a **bit depth** (16-bit or 24-bit). Higher values shall not be offered.
- The system shall offer only the sample rates supported by the selected device. If the device supports neither 44.1 nor 48 kHz natively, the system shall offer 48 kHz (converted from the device rate).
- When no saved quality exists for the selected device, the system shall use the highest offered quality (24-bit / highest offered sample rate).
- When the user changes the quality, the system shall save it locally for that device (device ID and numeric values only; no personal data) and use it for the next recording.
- When a saved quality is no longer offered by the device (for example, the sample rate is not supported), the system shall use the default from this RF and shall not delete the saved value.
- The source row (audio-devices-list RF-6) shall show the quality (for example, `Xone:96 · Stereo · 1–2 · 24-bit/48 kHz`). The source sheet shall contain a **Quality** section to change it.

### RF-2: Level meters
- While a valid source is selected and audio-input permission is granted, the system shall show a level meter per recorded channel (1 for mono; 2 labeled L and R for stereo) on the Record tab, both while idle and while recording.
- The meters shall show the current peak level and update smoothly in real time.
- When a channel reaches full scale (clipping), the system shall show a clipping indicator for that channel and keep it visible for at least 2 seconds after the last clip.
- When the source, channels, or permission change, the meters shall update to the new source; if there is no valid source or permission is missing, the meters shall be hidden and the source row state (audio-devices-list RF-6) explains why.
- Showing meters while idle shall not write any audio to storage.

### RF-3: Start recording
- The record button shall be enabled only when a valid source is selected (valid channel selection) and audio-input permission is granted.
- When the user taps the record button, the system shall start recording the selected channels at the selected quality into a new **CAF file with uncompressed PCM** (mono file for mono, stereo file for stereo with left/right as selected).
- When recording starts, the system shall show the recording state (RF-4) within about 1 second.
- If recording cannot start (for example, the device is unavailable or there is not enough free storage for at least 1 minute of recording), then the system shall show a small error message explaining why, stay idle, and leave no file behind.
- The first time the user starts a recording on iPhone/iPad, the system shall show a dismissible tip suggesting enabling Do Not Disturb, because calls pause the recording (RF-8). The tip shall not appear again after it is dismissed.

### RF-4: Recording state UI
- While recording, the Record tab shall show:
  - a `REC` indicator and the **elapsed time** (`H:MM:SS`), counting only recorded time (paused time excluded);
  - the current **file size** (for example, `412 MB`);
  - the **remaining recording time** estimated from free storage and the current quality (for example, `About 5 h left`);
  - the level meters (RF-2);
  - **Pause/Resume** and **Stop** buttons.
- While recording or paused, the source row shall be locked: it shall show the active source and quality but shall not open the source sheet.
- While paused, the system shall show a clear `PAUSED` state, keep the elapsed time frozen, and keep showing the meters.
- While recording or paused, the user may switch to the Sessions tab; a `REC` (or `PAUSED`) indicator with the elapsed time shall stay visible there, and tapping it shall return to the Record tab.

### RF-5: Pause and resume
- When the user taps **Pause**, the system shall stop writing audio to the file without closing it.
- When the user taps **Resume**, the system shall continue writing to the same file; the paused period shall not be part of the recording.
- Pause/Resume shall be available any number of times during a recording.

### RF-6: Stop and automatic save
- When the user taps **Stop** (while recording or paused), the system shall finish the file and save the session automatically with a date-based name (for example, `Session 2026-11-11 22.30`), using the date and time when the recording started.
- If a session with the same name already exists, the system shall add a number to make it unique (for example, `Session 2026-11-11 22.30 (2)`).
- After saving, the system shall return to the idle state and show a small confirmation (for example, "Saved: Session 2026-11-11 22.30").
- Saved sessions shall be stored in the app's local storage so that the session library feature can list them and they can be made visible in Files (iPhone/iPad) / Finder (Mac).
- If the recording contains no audio (stopped before any audio was written), the system shall discard it and not create a session.

### RF-7: Background recording and sleep
- While recording or paused, the system shall keep recording when the app goes to the background or the iPhone/iPad is locked.
- On Mac, while recording, the system shall prevent idle system sleep; when recording stops, normal sleep behavior shall return.

### RF-8: Interruptions
- **Device disconnected:** When the recording device disconnects while recording, the system shall pause automatically, keep the audio recorded so far, and show a notice ("<device> disconnected. Recording paused."). The device shall not be changed automatically while a recording exists (audio-devices-list RF-7).
  - While the device is disconnected, **Resume** shall be disabled and **Stop** shall save the session (RF-6).
  - When the same device reconnects, the system shall enable **Resume** to continue in the same file; it shall not resume automatically.
- **Call or another app taking audio (iPhone/iPad):** When the system interrupts audio input, the recording shall pause automatically and show a notice ("Recording paused by a call or another app."). When the interruption ends, the system shall not resume automatically; the user taps **Resume** when ready.
- **Mac:** Calls or other apps using audio input shall not pause the recording.
- **Low storage:** When the remaining recording time falls to about 10 minutes, the system shall show a warning once per recording. When the remaining recording time reaches about 1 minute, the system shall stop and save the session (RF-6) and show a notice explaining that storage is full.
- **App terminated during recording:** If the app is terminated (crash or system termination) while recording, the audio written so far shall remain in a readable file; on next launch the system shall save it as a session (RF-6 naming) and show a small notice that an interrupted recording was recovered.

### RF-9: Mac keyboard shortcuts and menu
- On Mac, the system shall provide a **Recording** menu in the menu bar with: **Record** (⌘R), **Pause/Resume** (Space), **Stop** (⌘R while recording, shown as **Stop**), and **Choose Source…**.
- Menu items shall be enabled only when the action is possible (for example, Record requires a valid source; Choose Source… is disabled while recording or paused).
- Space shall not trigger Pause/Resume while a text field has focus.
- On iPad with a hardware keyboard, the same shortcuts should work where the platform supports them.

## Non-Functional Requirements
- **NFR-1:** Works on iPhone, iPad, and Mac with platform-appropriate presentation; controls stay usable at large Dynamic Type sizes.
- **NFR-2:** Recorded audio is bit-accurate PCM at the selected quality: no dropped audio, gaps, or clicks during normal recording or at pause/resume boundaries.
- **NFR-3:** Recordings of several hours (at least 4 h of stereo 24/48, about 4 GB) work without file-size limits or growing memory use.
- **NFR-4:** Audio recorded before any interruption or termination is never lost (RF-8).
- **NFR-5:** Persisted settings contain no personal data (device IDs, quality values, and a tip-dismissed flag only). Audio files are stored only on the device; no backend or external services.
- **NFR-6:** Level meters and recording info update without visible lag and do not noticeably affect battery use while idle compared with recording.
- **NFR-7:** User-facing text is in English and understandable to non-technical users.

## Edge Cases
- Device supports only 96 kHz: 48 kHz is offered (converted) (RF-1).
- Mono built-in microphone: one meter, mono file (RF-2, RF-3).
- The user changes the channel selection while idle: meters follow the new channels immediately (RF-2).
- Record tapped with less than 1 minute of free storage: error, no file (RF-3).
- Stop tapped immediately after Record with no audio written: no session created (RF-6).
- Two recordings started in the same minute: names are made unique (RF-6).
- Device unplugged while paused: stays paused; Resume disabled until the same device reconnects (RF-8).
- A different external device connects while a recording exists: the source does not change (RF-8, audio-devices-list RF-7).
- Call arrives while already paused by the user: stays paused; no extra state change (RF-8).
- Low-storage limit reached while paused: the session is saved and the app returns to idle (RF-8).
- Permission revoked while recording (iOS Settings): the recording stops and the session is saved with what was recorded (RF-8, NFR-4).
- App terminated during recording: the session is recovered on next launch (RF-8).

## Out of Scope
- Session library: list, playback, rename, delete, trim, share/export, waveform (separate feature). Until it exists, the Sessions tab keeps its empty state except for the REC indicator (RF-4).
- First-use explanation screen before the permission prompt and the "Open Settings" notice (separate onboarding/permission work).
- Input monitoring (hearing the input through headphones), gain control in the app, markers/notes during recording.
- Sample rates above 48 kHz, bit depths other than 16/24, 32-bit float, compressed formats while recording.
- Multichannel recording (more than one stereo pair) and MIDI features.
- Recording from two devices at the same time.

## Completion Criteria
- The source row shows quality; the source sheet has a Quality section; defaults and per-device persistence follow RF-1.
- Level meters with clipping indicators are visible on the Record tab while idle and recording, for mono and stereo sources (RF-2).
- Record starts a CAF/PCM recording of the selected channels at the selected quality; record is disabled without a valid source or permission (RF-3).
- While recording: REC + elapsed time, file size, remaining time, meters, Pause/Resume, Stop; source row locked; REC indicator visible on the Sessions tab (RF-4).
- Pause/Resume continues in the same file without gaps (RF-5).
- Stop saves the session automatically with a unique date-based name and shows a confirmation; empty recordings are discarded (RF-6).
- Recording continues with the iPhone locked / app in background; the Mac does not idle-sleep while recording (RF-7).
- Disconnect, call (iPhone/iPad), low storage, and app termination follow RF-8 without losing recorded audio.
- On Mac, the Recording menu and shortcuts work as defined in RF-9.
- Verified on a real device with an external mixer/interface and with the built-in microphone, including a recording of at least 1 hour.

## Decisions (approved 2026-11-12)
- **Session storage format:** each session is one `.caf` file in a `Sessions` folder inside the app's Documents folder (visible in Files/Finder). The file name is the session name; date and duration are read from the file. No separate metadata file for now.
- **Name format:** `Session YYYY-MM-DD HH.mm` (dot instead of `:`, which is not safe in Mac file names).
- **Quality persistence:** saved per device; when nothing is saved, the highest offered quality is selected (RF-1).
- **Low-storage thresholds:** warning at about 10 minutes and automatic stop at about 1 minute of remaining recording time (RF-8).

## Open Questions
- None.
