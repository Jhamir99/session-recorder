# Session Recorder

Session Recorder is an early-stage iPhone, iPad, and Mac app for DJs and musicians to record practice and performance sessions from an audio device connected over USB-C (for example, a DJ mixer or audio interface). Sessions are recorded lossless (up to 24-bit/48 kHz) and can later be exported to other formats or compressed for sharing. This repository is part of a personal portfolio project.

## Status

**Early development.** The project currently focuses on audio input setup:

- Audio input device selection
- Audio input channel selection (mono or stereo)

## Product Vision

### Recording
- Record from a USB-C audio device, choosing which channels to record: one mono channel or one stereo pair.
- Lossless recording, up to **24-bit / 48 kHz**. By default, the app uses the highest quality supported by the device (capped at 24/48); the user can change it.
- Master file format: **CAF** with uncompressed PCM (Apple's native container: no 4 GB limit and stays readable if recording is interrupted). About 1 GB per hour for stereo 24/48. Converting to FLAC or other formats is done by the user via export.
- While recording: input level meters (with clipping warning), elapsed time, file size and free storage, pause/resume.
- Recording continues in the background (e.g., iPhone locked or app in background).

### Session library
- List recorded sessions and play them back.
- Rename and delete sessions.
- Trim the start/end of a session.
- Share sessions and make them visible in Files (iPhone/iPad) / Finder (Mac).

### Export and sharing
- Export formats: **WAV / AIFF**, **FLAC**, **ALAC (Apple Lossless)**, **AAC / M4A**.
- When sharing, the user can choose to compress the file (e.g., AAC at a chosen bitrate).
- MP3 is not planned: Apple frameworks provide no MP3 encoder, and the project avoids external dependencies.

### UI (agreed layout)
- **Navigation:** two tabs, **Record** and **Sessions** (shown as a sidebar on iPad/Mac via SwiftUI's adaptive tab view).
- **Record tab (idle):** a compact source row (device, channels, quality) that opens a sheet to change device, mono/stereo channels, and quality. Level meters are always visible once a source is selected, so gain can be set before recording. Large record button.
- **Record tab (recording):** source row locked; meters with clipping warning; `REC` indicator with elapsed time; file size and remaining recording time based on free storage; **Pause/Resume** and **Stop** buttons.
- **While recording:** the user can switch to the Sessions tab (a `REC` indicator stays visible); source and quality cannot change until recording stops.
- **On stop:** the session is saved automatically with a date-based name (e.g., "Session 2026-11-11 22:30"); it can be renamed later.
- **Sessions tab:** list of sessions (name, date, duration); swipe/context actions to rename and delete.
- **Session detail:** name (editable), date, duration, format, size; waveform with playback position; player controls; actions **Trim**, **Share**, **Delete**.
- **Share sheet (export + share in one flow):** choose format (Original CAF, WAV, AIFF, FLAC, ALAC, AAC with bitrate), see the estimated file size, then hand off to the system share sheet (AirDrop, Files, other apps).

- **Trim:** drag start/end handles on the waveform (exact times and resulting duration shown, with preview playback). Saving creates a new trimmed session; the original is kept.
- **First use:** a short screen explains why audio input access is needed, then shows the system permission prompt. If access is denied, a notice offers a button to open Settings.
- **No external device:** the built-in microphone is used, with a note asking to connect a mixer/interface over USB-C. When an external device connects, it is selected automatically.
- **Interruptions while recording:**
  - Device disconnected: recording pauses automatically with a notice; if the same device reconnects, the user can resume in the same file or stop and save.
  - Phone/FaceTime call or another app taking audio (iPhone/iPad): recording pauses automatically; the user resumes when ready. iOS does not allow apps to keep recording during a call. The first time the user records, a dismissible tip suggests enabling Do Not Disturb.
  - On Mac, calls in other apps do not interrupt recording (macOS allows concurrent audio input).
  - Low storage: warning when about 10 minutes of recording time remain; at the limit, recording stops and the session is saved.
- **Mac extras:** keyboard shortcuts (e.g., ⌘R record/stop, Space pause/play, ⌘⌫ delete session) and a **Recording** menu in the menu bar (Record, Pause, Stop, Choose Source…).

### Out of scope (for now)
- MIDI features (the MIDI entitlement is kept for future use).
- Multichannel recording (more than one stereo pair).
- Backend, accounts, or cloud services.

### Open Questions
- Session metadata (name, date, duration, notes) storage format.

## Overview

- **Platforms:** iPhone, iPad, Mac (project also builds for visionOS; not a priority)
- **UI:** SwiftUI
- **Stack:** Apple frameworks only (no external dependencies, no backend)
- **Project:** `Session Recorder.xcodeproj` (scheme/target: `Session Recorder`)

## Build and Run

### Requirements

- A Mac with an Xcode version that supports the project's deployment targets (currently 27.0 for iOS/macOS)

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/Jhamir99/session-recorder.git
   cd session-recorder
   ```
2. Open `Session Recorder.xcodeproj` in Xcode.
3. Select the **Session Recorder** scheme.
4. Build and run on **My Mac**, an iPhone/iPad simulator, or a connected device.

> Note: Features that access audio input require microphone/audio input permission when you run the app.

## License

Copyright (c) 2026 Jhamir99. **All rights reserved.**

This source code is publicly available for **viewing and evaluation purposes only** (for example, portfolio/CV review). No permission is granted to use, copy, modify, distribute, or create derivative works without prior written permission. See [`LICENSE`](./LICENSE) for details.

## Branding

The **Session Recorder** name, and any associated logos, icons, visual assets, or branding (including any future app icon), are **not** licensed for reuse or imitation. The project/brand name may change in the future.
