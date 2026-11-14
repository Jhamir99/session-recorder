# Plan: Spanish Localization

## References
- `docs/constitution.md` (C1–C6)
- `specs/localization/spec.md` (RF-1–RF-6, NFR-1–NFR-5, Glossary, Decisions)
- All feature specs (texts come from `audio-devices-list`, `recording`, `session-library`, `first-use`, `settings`).

## 1) Files to create or modify
| File | Action | Responsibility | RF |
|---|---|---|---|
| `Session Recorder/Localizable.xcstrings` | Create | String Catalog: English source strings (extracted by Xcode) + Spanish (`es`) translations, plural variations, comments for translators. | RF-1–RF-3, NFR-5 |
| `Session Recorder/InfoPlist.xcstrings` | Create | Spanish microphone usage description (`NSMicrophoneUsageDescription`). | RF-2 |
| `Session Recorder.xcodeproj/project.pbxproj` | Modify | Add `es` to `knownRegions` (catalogs and string extraction are already enabled: `LOCALIZATION_PREFERS_STRING_CATALOGS`, `SWIFT_EMIT_LOC_STRINGS`). | RF-1 |
| Swift files with user-facing text (all features) | Modify | Make every shown text localizable: literals in SwiftUI views are already extracted; computed `String`s (enum titles, notices, messages, helpers, accessibility labels/values, menu titles built from variables) become `String(localized:)` with a translator comment; texts that must not change (`REC`, `CLIP`, `L`, `R`, `M`, format names) use `Text(verbatim:)` or are excluded. | RF-2, RF-3, RF-5, NFR-5 |
| `RecordingLogic.swift`, `SettingsLogic.swift`, `SessionLibraryLogic.swift` | Modify | Formatting helpers that build sentences ("About 5 h left", "12 sessions · …") use localized format strings with plural variants; numbers/sizes/dates keep using locale-aware formatters. | RF-3, RF-4 |
| Views with long texts | Modify (only if needed) | Allow wrapping where Spanish is longer (no truncation). | RF-6 |
| Preview files | Modify | Spanish variants of key previews (`.environment(\.locale, Locale(identifier: "es"))`). | C5, RF-6 |
| `AGENTS.md`, `docs/project-structure.md`, `README.md`, `Session Recorder/MEMORY.md` | Modify | How to add strings and translations. | C2, NFR-5 |

## 2) Technical design
- **String Catalogs** (Apple, no dependency): Xcode extracts `Text("…")`, `Button("…")`, `Label("…")`, `.navigationTitle("…")`, `String(localized: "…")`, etc. into `Localizable.xcstrings` at build time; translations are stored next to the English source.
- **Strings with values:** `String(localized: "Saved: \(name)")` → key `Saved: %@`; Spanish reorders freely (`Guardada: %@`).
- **Plurals:** keys like `%lld sessions` get plural variations (one/other) in both languages.
- **Info.plist:** `InfoPlist.xcstrings` localizes the generated `NSMicrophoneUsageDescription` key.
- **Not translated:** user content (session names), brand/format names, mixer indicators (`REC`, `CLIP`, `L`, `R`, `M`), the default prefix "Session" (approved decisions).
- **Formats:** dates (`.dateTime`), sizes (`ByteCountFormatter`), percentages and numbers already follow the locale; `H:MM:SS` stays as is.
- **Checking completeness:** `xcodebuild -exportLocalizations -exportLanguage es` exports an `.xcloc`; every string must have a Spanish translation (none "new" or "needs review").

## 3) Decisions approved before implementation (2026-11-14)
1. **New files:** `Session Recorder/Localizable.xcstrings` and `Session Recorder/InfoPlist.xcstrings`.
2. **Project change:** add `es` to `knownRegions` in `project.pbxproj`.

## 4) Verification strategy (C5)
| Strategy | How | RF |
|---|---|---|
| Completeness | Export localizations for `es`; 0 untranslated strings. | RF-2 |
| Build | `xcodebuild` macOS + iOS Simulator (scratch DerivedData). | NFR-1 |
| Previews | Spanish previews of the main screens. | RF-6 |
| Real devices | iPhone and Mac in Spanish (and app language override back to English): every screen, Mac menus, notices with values, plurals, microphone prompt (after a permission reset), VoiceOver spot check, large Dynamic Type. | RF-1–RF-6 |
