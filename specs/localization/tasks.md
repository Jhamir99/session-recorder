# Tasks: Spanish Localization

Source: `specs/localization/spec.md`, `specs/localization/plan.md`.
Constraints: C1–C6 (Apple tools only, no deps, English base, no behavior or data changes). Keep tasks small, in dependency order. Paths are relative to `Session Recorder/`.

## Tasks

- [x] **T1 — Project setup** (`Localizable.xcstrings`, `InfoPlist.xcstrings`, `project.pbxproj`)
  - **RF:** RF-1
  - **Depends on:** none
  - **Done when:** `es` is a known region; both catalogs exist and the app builds on Mac and iOS.

- [ ] **T2 — Make every user-facing text localizable** (Swift files in all features)
  - **RF:** RF-2, RF-3, RF-5, NFR-5
  - **Depends on:** T1
  - **Done when:** Computed texts (enum titles, notices, messages, helpers, menu titles, accessibility) use `String(localized:)` with comments; non-translatable texts are verbatim; an `es` export lists every visible English text and none of the excluded ones.

- [ ] **T3 — Plurals and sentences with values** (`Localizable.xcstrings`, logic helpers)
  - **RF:** RF-3, RF-4
  - **Depends on:** T2
  - **Done when:** Session counts, minutes/hours, remaining time and notices with values have plural variants and whole-sentence keys; dates/sizes follow the locale.

- [ ] **T4 — Spanish: recording, audio source and first use** (`Localizable.xcstrings`, `InfoPlist.xcstrings`)
  - **RF:** RF-2
  - **Depends on:** T3
  - **Done when:** Record tab, source sheet, meters, notices, tips, first-use screens and the microphone prompt are translated with the glossary.

- [ ] **T5 — Spanish: library, export, settings and menus** (`Localizable.xcstrings`)
  - **RF:** RF-2
  - **Depends on:** T3
  - **Done when:** Sessions tab, detail, trim, rename/delete, share/export, settings and Mac Recording/Session menus are translated; the `es` export has no untranslated strings.

- [ ] **T6 — Layout check in Spanish** (views as needed, previews)
  - **RF:** RF-6
  - **Depends on:** T4, T5
  - **Done when:** No truncated or overlapping Spanish text on iPhone, iPad and Mac, including large Dynamic Type; Spanish previews exist for the main screens.

- [ ] **T7 — Docs** (`AGENTS.md`, `docs/project-structure.md`, `README.md`, `MEMORY.md`)
  - **RF:** C2, NFR-5
  - **Depends on:** T6
  - **Done when:** Docs explain that new texts must be localizable and translated in the catalog.

- [ ] **T8 — Verification pass**
  - **RF:** RF-1–RF-6, NFR-1–NFR-5
  - **Depends on:** T1–T7
  - **Done when:** `xcodebuild` succeeds for macOS and an iOS Simulator; `es` export has 0 untranslated strings; checked on a real iPhone and Mac in Spanish and English (menus, notices, plurals, microphone prompt, VoiceOver spot check, large text).
