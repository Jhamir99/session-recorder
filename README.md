# Session Recorder

Session Recorder is an early-stage macOS app for DJs and musicians to capture practice and performance sessions from audio and MIDI devices. This repository is part of a personal portfolio project.

## Status

**Early development.** The project currently focuses on audio input setup:

- Audio input device selection
- Audio input channel selection

Planned areas (not yet implemented) include session recording workflows and MIDI device support.

## Overview

- **Platform:** macOS
- **UI:** SwiftUI
- **Stack:** Apple frameworks only (no external dependencies, no backend)
- **Project:** `Session Recorder.xcodeproj` (scheme/target: `Session Recorder`)

## Build and Run

### Requirements

- macOS with a recent version of Xcode installed (Xcode 15+ recommended)
- An Apple Mac capable of running the selected Xcode/macOS SDK

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/Jhamir99/session-recorder.git
   cd session-recorder
   ```
2. Open `Session Recorder.xcodeproj` in Xcode.
3. Select the **Session Recorder** scheme.
4. Build and run on **My Mac**.

> Note: Features that access audio input may require macOS microphone/audio input permission when you run the app.

## License

Copyright (c) 2026 Jhamir99. **All rights reserved.**

This source code is publicly available for **viewing and evaluation purposes only** (for example, portfolio/CV review). No permission is granted to use, copy, modify, distribute, or create derivative works without prior written permission. See [`LICENSE`](./LICENSE) for details.

## Branding

The **Session Recorder** name, and any associated logos, icons, visual assets, or branding (including any future app icon), are **not** licensed for reuse or imitation. The project/brand name may change in the future.
