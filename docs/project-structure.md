# Project Structure — Session Recorder

This document describes the repository layout and feature code organization. Keep it durable and high-signal; update it when structure changes.

## Repository layout
- `AGENTS.md` — canonical agent instructions for this repo.
- `README.md` — project overview and product vision (scope, planned features, open questions).
- `Session Recorder.xcodeproj/` — Xcode project (scheme/target: `Session Recorder`).
- `Session-Recorder-Info.plist` — Info.plist keys that cannot be generated from build settings (iOS `UIBackgroundModes = audio`); merged with the generated Info.plist.
- `Session Recorder/` — app source root used by the Xcode target (synchronized root group).
- `docs/` — project-level documentation (e.g., `constitution.md`, `project-structure.md`).
- `specs/<feature>/` — feature specs, plans, and tasks (what/why/acceptance; plans map files and RFs).

## App source layout
- `Session Recorder/MyApp.swift` — app entry (`@main`) and menu commands.
- `Session Recorder/ContentView.swift` — app shell (Record/Sessions tabs, source sheet).
- `Session Recorder/Features/<FeatureName>/` — feature code (preferred for non-trivial features).
- `Session Recorder/MEMORY.md` — short session/project log.

## Feature folder pattern
Use a feature folder when a capability has multiple types or UI states:

```text
Session Recorder/Features/<FeatureName>/
  <FeatureName>Models.swift           (value types, UI/message state; no I/O)
  <FeatureName>Logic.swift            (pure/testable decisions; explicit inputs)
  <FeatureName>Service.swift          (Apple API/device/permission boundary)
  <FeatureName>Repository.swift       (local persistence; IDs only, no personal data unless approved)
  <FeatureName>ViewModel.swift        (coordinates service + logic + repository; UI state)
  <FeatureName>ViewModel+*.swift      (focused extensions when the view model grows)
  Views/
    <FeatureName>View.swift           (composition / entry view)
    <FeatureName>View+Previews.swift  (preview data and #Preview states)
    <SubView>.swift                   (focused subviews)
```

Not every feature needs every file. Keep it simple (Constitution C1). Current examples: `Features/AudioDevicesList/` (device and channel selection) and `Features/Recording/` (capture service, session file store, recording logic/settings, `RecordingViewModel` + `+Interruptions`, views and `RecordingCommands`).

## Boundaries (Constitution C4)
- **Views** render state and emit user intent; they do not perform device discovery, permission I/O, persistence, or core selection rules.
- **Logic** is pure/deterministic where practical (explicit inputs, no I/O) so behavior is testable/verifiable.
- **Service** owns Apple API integration (AVFoundation/CoreAudio/MIDI as appropriate).
- **Repository** owns local persistence; persisted data must follow approved constraints (e.g., device/channel IDs only, no personal data).
- **View model** coordinates boundaries and exposes UI-ready state.

## File-split conventions
- Split large files by responsibility when scanning becomes difficult (e.g., `ViewModel+DeviceSelection.swift`, `ViewModel+ChannelSelection.swift`, `View+Previews.swift`).
- Prefer extensions/separate files over new abstractions. Avoid speculative protocols/types (C1).
- Keep previews in dedicated `*+Previews.swift` files when preview data is substantial (Constitution C5).
- When moving/renaming files or folders, update `AGENTS.md` and relevant `specs/<feature>/{plan,tasks}.md` to keep paths trustworthy (Constitution C2).

## Naming notes
- Use descriptive English names.
- Persistence components for local selection/config state may be named `Repository` (current convention) unless a different name is clearer; keep naming consistent within a feature.
- Spec/plan/task checkboxes should reflect the actual paths and names after refactors.
