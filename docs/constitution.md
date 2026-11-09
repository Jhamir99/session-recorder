# Constitution — Session Recorder

1. **Simple stack**: Use only SwiftUI and Apple APIs; no dependencies, frameworks, backend, build steps, or code generation.
2. **Spec leads, code follows**: The spec defines approved scope and UX; code implements it; behavior changes update the spec.
3. **Spec ≠ implementation**: Specs describe *what* and verifiable criteria, not classes, signatures, or internal details unless explicitly required.
4. **Separate logic from UI**: MIDI/audio capture, state, and file handling live in services/models; Views only present state and user intent.
5. **Tests without dependencies**: Verify with Xcode/`#Preview`/`xcodebuild`; do not add test frameworks; add tests only with a native target when valuable.
6. **Minimal, verifiable changes**: Make only requested changes, keep Apple-platform support, keep text/code in English, and ask before new files or persisted-data format changes.
