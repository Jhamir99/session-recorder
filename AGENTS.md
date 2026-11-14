# AGENTS.md — Session Recorder
SwiftUI app (early stage) for DJs/musicians to record sessions from a USB-C audio device (e.g., Xone/Pioneer mixer) on iPhone, iPad, and Mac. Goal: no backend/external dependencies.

## Product scope (summary; full vision in `README.md`)
- Lossless recording at 44.1/48/88.2/96 kHz (as supported by the device), 16/24-bit; default = 24-bit/48 kHz, user can change it per device.
- Record one mono channel or one stereo pair. Master format: CAF (uncompressed PCM); FLAC and other formats only via user export.
- Recording UI: level meters, elapsed time, file size/free space, pause/resume, background recording.
- Library: list, play, rename, delete, trim, share/Files visibility.
- Export: WAV/AIFF, FLAC, ALAC, AAC/M4A; optional compression when sharing. No MP3 (no native encoder).
- UI: tabs Record/Sessions; source row + sheet; meters always on; auto-named save on stop; session detail with waveform/player/trim/share; single share sheet with format choice; trim saves a new copy; auto-pause on disconnect/call; built-in mic fallback; Mac shortcuts + Recording menu (see README "UI").
- Out of scope for now: MIDI features, multichannel recording.

## Facts (from project)
- Xcode project: `Session Recorder.xcodeproj`, scheme/target: `Session Recorder`.
- Swift 5 (`SWIFT_VERSION=5.0`), generated Info.plist merged with `Session-Recorder-Info.plist` (iOS `UIBackgroundModes = audio`, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`), bundle `com.jhamirfranciscopiminchumopersonalteam.SessionRecorder`.
- Platforms in project settings: `iphoneos iphonesimulator macosx xros xrsimulator` (`TARGETED_DEVICE_FAMILY=1,2,7`); deployment targets are set to `27.0` in `project.pbxproj` (verify in Xcode before changing).
- Entitlements (`Session Recorder/Session Recorder.entitlements`): App Sandbox, `com.apple.security.device.midi`, `com.apple.security.device.audio-input`; user-selected files read-write via `ENABLE_USER_SELECTED_FILES = readwrite` (Mac Save… when exporting). Microphone usage description is set via `INFOPLIST_KEY_NSMicrophoneUsageDescription` in `project.pbxproj`.
- No test targets, CI workflows, package manifests, or lint/format config found.

## Code layout
- App entry/UI shell: `Session Recorder/MyApp.swift` (`@main`, Recording menu commands), `Session Recorder/ContentView.swift` (Record/Sessions tabs).
- Feature code: `Session Recorder/Features/<FeatureName>/` (`Features/AudioDevicesList/`, `Features/Recording/`, `Features/SessionLibrary/`, `Features/FirstUse/`, `Features/Settings/`). Keep SwiftUI views in `Views/`; keep device/audio state, services, selection logic, and persistence/repository logic outside Views (see Constitution C4).
- `Session Recorder/MEMORY.md`: short project/session log (keep concise).

## Project structure
- Follow the feature-folder pattern and file-split conventions in `docs/project-structure.md`.
- Product/engineering constraints: `docs/constitution.md`. Feature specs/plans/tasks: `specs/<feature>/`.

## Commands
- Primary dev loop: open `Session Recorder.xcodeproj` in Xcode; use SwiftUI `#Preview` and run on a chosen simulator/device.
- CLI build (macOS): `xcodebuild -project "Session Recorder.xcodeproj" -scheme "Session Recorder" -configuration Debug -destination 'platform=macOS' build`
- CLI build (iOS Simulator, pick an available one): `xcodebuild -project "Session Recorder.xcodeproj" -scheme "Session Recorder" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build` (list available ones with `xcrun simctl list devices available`)

## Conventions / constraints
- UI text and code comments in English.
- Keep code simple and names descriptive; avoid speculative abstractions.
- No dependencies, frameworks, or build step. Do not add backend/external services.
- Make only requested, focused changes; avoid rewrites.
- Ask before creating new files or changing persisted data formats.
- New UI must work on iPhone/iPad/Mac (and respect current multiplatform setup) unless the user narrows scope.
