# Spec: Spanish Localization

## Context and Goal
All user-facing text in Session Recorder is in English. This feature adds a Spanish translation. The app shall follow the language chosen in the system (iPhone/iPad/Mac language, or the per-app language the system offers in Settings); there is no language option inside the app. English remains the base language and the fallback for any other language.

## Users
- Spanish-speaking DJs and musicians who use their device in Spanish.

## User Stories
- As a Spanish-speaking user, I want the whole app in Spanish when my device is in Spanish, without changing anything in the app.
- As a user, I want dates, numbers, file sizes and durations written the way they are written in my language.
- As a user, I want to be able to use the app in English on a Spanish device by choosing the app's language in the system Settings.

## Functional Requirements

### RF-1: Language selection
- When the system's preferred language (or the app's language chosen in the system Settings) is Spanish, the app shall show all its text in Spanish; otherwise it shall show English.
- The app shall not offer a language option of its own.
- Changing the system or per-app language shall take effect the next time the app opens (system behavior).

### RF-2: Coverage
The Spanish translation shall cover every user-facing text, including:
- Tabs, titles, buttons, menus (including the Mac **Recording** and **Session** menus and their items), toolbar help, and keyboard-shortcut labels shown by the system.
- Source sheet, channel selection, quality section, level meter labels and the Record tab (status, notices, tips, USB-C note).
- Session library: list, row texts, detail, player, trim, rename, delete confirmation, share/export sheet, progress, errors.
- First use: explanation, access notices.
- Settings: section titles, option names, values and hints.
- Notices and errors that include values (session names, minutes, sizes, device names).
- The microphone permission text shown by the system prompt.
- Accessibility labels, values and hints (VoiceOver).

### RF-3: Values inside text
- Texts that include values shall be translated as whole sentences, so word order and grammar are correct in Spanish (for example, "Saved: Session 2026-11-14 22.30.15" → "Guardada: …").
- Counts shall use correct singular/plural forms in both languages (for example, "1 session" / "12 sessions" → "1 sesión" / "12 sesiones"; minutes and hours).

### RF-4: Dates, numbers and sizes
- Dates, times, durations, decimal numbers and file sizes shall be formatted according to the user's language and region (for example, `4,2 GB` and Spanish month and weekday names in a Spanish region).
- Elapsed/playback times keep the `H:MM:SS` form in both languages.

### RF-5: What is not translated
- Session names and other user content (including existing file names) are never changed.
- Brand and technical names stay as they are: Session Recorder, CAF, WAV, AIFF, FLAC, ALAC, AAC, USB-C, kHz, dBFS.
- Audio indicators used on mixers stay as they are: `REC`, `CLIP`, `L`, `R`, `M`.
- The default session name prefix stays "Session" (settings RF-7).

### RF-6: Layout
- Spanish texts are often longer than English; no text shall be cut off or overlap on iPhone, iPad or Mac, including at large Dynamic Type sizes (texts may wrap).

## Non-Functional Requirements
- **NFR-1:** Only Apple localization tools; no translation service or dependency.
- **NFR-2:** Terminology is consistent across the app (one Spanish term per concept; see the glossary).
- **NFR-3:** Translations are natural, short and understandable to non-technical users.
- **NFR-4:** Adding Spanish does not change behavior or stored data.
- **NFR-5:** New texts added later can be found and translated easily (no hard-coded strings that bypass translation).

## Glossary (approved)
| English | Spanish |
|---|---|
| Record / Recording | Grabar / Grabación |
| Session / Sessions | Sesión / Sesiones |
| Audio source / Input | Fuente de audio / Entrada |
| Channel / Mono / Stereo | Canal / Mono / Estéreo |
| Quality / Sample rate / Bit depth | Calidad / Frecuencia de muestreo / Profundidad de bits |
| Level meter / Peak hold | Vúmetro / Retención de picos |
| Pause / Resume / Stop | Pausar / Reanudar / Detener |
| Fade | Fundido |
| Trim | Recortar |
| Share / Export | Compartir / Exportar |
| Rename / Delete / Move to Trash | Renombrar / Eliminar / Mover a la papelera |
| Storage | Almacenamiento |
| Settings | Ajustes |

## Edge Cases
- Device in Spanish (Latin America or Spain): Spanish texts; dates and numbers follow the region (RF-1, RF-4).
- Device in another language (French, German…): English (RF-1).
- Device in Spanish with the app set to English in Settings: English (RF-1).
- Long Spanish texts in Mac menus and narrow iPhone rows: no truncation (RF-6).
- A notice with a long session name: wraps without cutting the message (RF-3, RF-6).

## Out of Scope
- Languages other than English and Spanish.
- App Store metadata, screenshots and website text.
- Translating user content (session names) or changing existing file names.

## Completion Criteria
- With the device (or app) in Spanish, every screen, menu, sheet, notice, error, hint and the microphone prompt are in Spanish; in English they are unchanged (RF-1, RF-2).
- Plurals and texts with values read correctly in both languages (RF-3).
- Dates, sizes and numbers follow the region (RF-4).
- No truncated or overlapping text on iPhone, iPad and Mac in Spanish, including large Dynamic Type (RF-6).
- VoiceOver reads Spanish labels (RF-2).
- Verified on a real iPhone and Mac in Spanish and in English.

## Decisions (approved 2026-11-14)
- **Variant:** one neutral Spanish (`es`) for all regions.
- **Default session name prefix:** stays "Session" in every language (names do not depend on the language).
- **Mixer indicators:** `REC`, `CLIP`, `L`, `R`, `M` stay in English.
- **Glossary:** approved as listed.

## Open Questions
- None.
