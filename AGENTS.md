# AGENTS.md — Session Recorder
SwiftUI app (early stage) for DJs/musicians to record sessions from an audio/MIDI device (e.g., Xone/Pioneer). Goal: no backend/external dependencies; usable on Apple platforms.

## Facts (from project)
- Xcode project: `Session Recorder.xcodeproj`, scheme/target: `Session Recorder`.
- Swift 5 (`SWIFT_VERSION=5.0`), generated Info.plist, bundle `com.jhamirfranciscopiminchumopersonalteam.SessionRecorder`.
- Platforms in project settings: `iphoneos iphonesimulator macosx xros xrsimulator` (`TARGETED_DEVICE_FAMILY=1,2,7`); deployment targets are set to `27.0` in `project.pbxproj` (verify in Xcode before changing).
- Entitlements (`Session Recorder/Session Recorder.entitlements`): App Sandbox, `com.apple.security.device.midi`, `com.apple.security.device.audio-input`. Microphone usage description is set via `INFOPLIST_KEY_NSMicrophoneUsageDescription` in `project.pbxproj`.
- No test targets, CI workflows, package manifests, or lint/format config found.

## Code layout
- App entry/UI shell: `Session Recorder/MyApp.swift` (`@main`), `Session Recorder/ContentView.swift`, `Session Recorder/RecordButton.swift`.
- Shared constants/types: `Session Recorder/CONSTANTS.swift`.
- Feature code: `Session Recorder/Features/<FeatureName>/` (e.g., `Features/AudioDevicesList/`). Keep SwiftUI views in `Views/`; keep device/audio state, services, selection logic, and persistence/repository logic outside Views (see Constitution C4).
- `Session Recorder/MEMORY.md`: short project/session log (keep concise).

## Project structure
- Follow the feature-folder pattern and file-split conventions in `docs/project-structure.md`.
- Product/engineering constraints: `docs/constitution.md`. Feature specs/plans/tasks: `specs/<feature>/`.

## Commands
- Primary dev loop: open `Session Recorder.xcodeproj` in Xcode; use SwiftUI `#Preview` and run on a chosen simulator/device.
- CLI build (macOS): `xcodebuild -project "Session Recorder.xcodeproj" -scheme "Session Recorder" -configuration Debug -destination 'platform=macOS' build`
- CLI build (iOS Simulator, pick an available one): `xcodebuild -project "Session Recorder.xcodeproj" -scheme "Session Recorder" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build`

## Conventions / constraints
- UI text and code comments in English.
- Keep code simple and names descriptive; avoid speculative abstractions.
- No dependencies, frameworks, or build step. Do not add backend/external services.
- Make only requested, focused changes; avoid rewrites.
- Ask before creating new files or changing persisted data formats.
- New UI must work on iPhone/iPad/Mac (and respect current multiplatform setup) unless the user narrows scope.
