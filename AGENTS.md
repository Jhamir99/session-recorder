# AGENTS.md — Session Recorder

This repository uses a canonical agent guide at `Session Recorder/AGENTS.md`.

## Read first
- `Session Recorder/AGENTS.md` — project facts, commands, conventions, and structure summary.
- `docs/constitution.md` — non-negotiable engineering/product constraints.
- `docs/project-structure.md` — feature-folder and file-split conventions.
- `specs/<feature>/` — feature `spec.md`, `plan.md`, and `tasks.md` (when working on a feature).

## Quick facts
- SwiftUI app (early stage) for DJs/musicians to record sessions from audio/MIDI devices; no backend/external dependencies.
- Xcode project: `Session Recorder.xcodeproj`, scheme/target `Session Recorder`.
- Keep changes small, in English, Apple-API only, and aligned with the Constitution/specs.
