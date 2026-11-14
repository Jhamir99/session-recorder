# Spec: Settings

## Context and Goal
Session Recorder has no settings today: meter look, pause behavior, naming and library options are fixed. This feature adds a Settings screen (Recording, Library, Appearance), a sort option inside the session library, and a small storage status line at the bottom of the library, like Finder's status bar. All settings are stored on the device and apply immediately.

## Users
- DJs/musicians who want the meters, recording behavior and library to fit how they work.

## User Stories
- As a user, I want to choose how the level meters look and how long peaks stay visible, so I can set the gain on my mixer quickly.
- As a user, I want pauses to sound clean in the recording.
- As a user, I want my iPhone screen to stay on while recording, so I can watch the meters.
- As a user, I want my recordings named my way (for example, "Set 2026-11-14 22.30.15").
- As a user, I want protection if I forget to stop a recording, and an earlier low-storage warning if I prefer.
- As a user, I want to sort my sessions and see how much space they use and how much is left.
- As a user, I want to choose the app theme and the waveform style.

## Functional Requirements

### RF-1: Settings screen
- On Mac, the system shall provide **Settings…** (⌘,) in the app menu, opening the standard settings window.
- On iPhone/iPad, the Record and Sessions tabs shall show a **Settings** (gear) button in their navigation bars that opens Settings as a sheet with a **Done** button (no separate Settings tab).
- When the tab sidebar is shown (Mac, iPad), a **Settings** button (gear and text) sits at the bottom left of the sidebar.
- Settings shall be grouped into **Recording**, **Library** (sessions folder, see `specs/sessions-folder/`), **Export** (default export format, RF-10) and **Appearance**; options that are not obvious (peak hold, fade at pause, recording time limit, low-storage warning, session name) show a short hint under their name.
- Changes shall apply immediately and be saved on the device (no Save button); they shall survive restarts.
- While a recording exists, options that would change it (name prefix, time limit) shall apply from the next recording; display options (meters, theme) apply immediately.

### RF-2: Meter style (Recording)
- Options: **Continuous** (the current bar) and **Segmented** (24 thin blocks like LED meters), with the same dB scale and green/yellow/red zones. (LED and Round LED styles were tried and removed, 2026-11-14.)
- Default: Continuous.

### RF-3: Peak hold (Recording)
- Options: **Off**, **1 second** (default), **3 seconds**, **Until reset**.
- When on, each meter shall show a thin marker at the highest recent level, kept for the chosen time; with **Until reset**, the marker stays until the user taps/clicks the meters.
- The clipping indicator (recording RF-2) is unchanged.

### RF-4: Fade at pause and resume (Recording)
- Options: **Off** (the earlier behavior: audio is joined directly and a click can be heard), **Short** (about 20 ms fade-out before the pause point and fade-in after resuming, just enough to remove the click) and **Long** (about 200 ms, a softer transition).
- Default: Short.
- Only the moments around a pause change; the rest of the audio is untouched (bit-exact).

### RF-5: Keep screen on while recording (Recording, iPhone/iPad only)
- When on (default), the screen shall not dim or lock automatically while recording or paused; normal behavior returns when the recording stops.
- Changing the option during a recording applies immediately.
- Recording continues if the user locks the device anyway (recording RF-7).
- Not shown on Mac (the Mac already avoids idle sleep while recording, recording RF-7).

### RF-6: (Removed 2026-11-14)
- "Quality for new devices" was dropped: new devices keep the recording default (24-bit / 48 kHz, recording RF-1) and the quality is chosen per device in the source sheet.

### RF-7: Session name prefix (Recording)
- A text field for the first word of new session names (default **Session**), for example `Set` → `Set 2026-11-14 22.30.15`.
- The same rules as rename apply (library RF-3): not empty, no `/` or `:`; an invalid value is explained and the last valid prefix is kept. Maximum 30 characters.
- Applies to new and recovered recordings; existing sessions are not renamed.

### RF-8: Recording time limit (Recording)
- Options: **Off**, **1 hour**, **2 hours**, **4 hours**, **8 hours**.
- When the recorded time (paused time excluded) reaches the limit, the system shall stop and save the session and show a notice ("Recording stopped after 2 hours (time limit). Saved: …").
- Default: Off.

### RF-9: Low-storage warning (Recording)
- Options: warn when about **10**, **30** or **60 minutes** of recording time remain (recording RF-8). Default: 10 minutes.
- The automatic stop at about 1 minute is unchanged.

### RF-10: Default export format (Library)
- Options: **Last used** (current behavior) or a fixed format (Original, WAV, AIFF, FLAC, ALAC, AAC with bitrate).
- With a fixed format, the share sheet (library RF-6) always opens with it; the user can still change it there.

### RF-11: Session order (in the library, not in Settings)
- The Sessions tab shall offer a sort control (toolbar menu) with **Newest First** (default), **Oldest First** and **Name**.
- The choice shall be remembered.

### RF-12: Storage status line (in the library)
- At the bottom of the session list, the system shall show a small, secondary line with the number of sessions, the space they use and the free space on the device, for example `12 sessions · 4.2 GB · 85 GB available`.
- It shall update when sessions are added, trimmed, renamed or deleted, and when the app becomes active.
- It shall be shown on iPhone, iPad and Mac (Mac: like Finder's status bar under the list).

### RF-13: Theme (Appearance)
- Options: **System** (default), **Light**, **Dark**; applies to the whole app immediately.

### RF-14: Waveform style (Appearance)
- Options: **Bars** (current, default) and **Line** (a continuous filled outline); applies to the session detail and trim.

## Non-Functional Requirements
- **NFR-1:** Works on iPhone, iPad and Mac with platform-appropriate presentation (Mac settings window, iOS sheet); readable at large Dynamic Type sizes; VoiceOver labels for every option.
- **NFR-2:** Settings are stored locally with versioned keys; no personal data (the name prefix is user text used only for file names).
- **NFR-3:** Meter options do not noticeably increase CPU use while idle (recording NFR-6).
- **NFR-4:** The fade (RF-4) never changes audio outside the chosen fade length around a pause point.
- **NFR-5:** Only Apple frameworks; user-facing text in English.

## Edge Cases
- Prefix changed while recording: the current recording keeps the prefix it started with (RF-1, RF-7).
- Prefix with leading/trailing spaces: trimmed; empty after trimming → not accepted (RF-7).
- Time limit lowered below the current elapsed time while recording: applies from the next recording (RF-1).
- Time limit reached while paused: cannot happen (paused time is not counted).
- Fade on and the user stops right after resuming (less audio than the fade length): the fade is applied to what exists; no error (RF-4).
- Fade on and a pause caused by a disconnect: the audio stops at the disconnect without a fade-out (there is no more input), fade-in still applies on resume (RF-4, recording RF-8).
- Fixed export format AAC and a 96 kHz session: exported at 48 kHz as today (library RF-6).
- Sort by Name with names that differ only by case/numbers: natural order (`Set 2` before `Set 10`) (RF-11).
- Theme Dark while the system is Light: the whole app, including sheets, is dark (RF-13).

## Out of Scope
- Pre-recording buffer, voice/signal-activated recording, automatic silence trimming (possible future features).
- Syncing settings between devices (iCloud).
- Changing the language inside the app (the Spanish localization follows the system language; separate feature).

## Completion Criteria
- Settings open with ⌘, on Mac and the gear (Record and Sessions tabs) on iPhone/iPad; every option in RF-2–RF-10, RF-13, RF-14 works and is remembered (RF-1).
- Segmented meters and peak hold behave as described; fade removes the click at pause/resume without changing the rest of the audio (checked by comparing files) (RF-2–RF-4).
- Screen stays on while recording on iPhone when enabled (RF-5).
- New recordings use the prefix; the time limit stops and saves (RF-7, RF-8).
- Low-storage warning follows the chosen threshold (RF-9).
- Default export format is applied in the share sheet (RF-10).
- The library can be sorted from its toolbar and shows the storage line (RF-11, RF-12).
- Verified on a real iPhone and Mac.

## Decisions (approved 2026-11-14)
- **Where:** Mac Settings window (⌘,); iPhone/iPad gear button in the Record and Sessions tabs opening a sheet; no Settings tab.
- **Defaults:** meter Continuous, peak hold 1 second, fade Short, keep screen on On, prefix "Session", time limit Off, low-storage warning 10 minutes, export Last used, order Newest First, theme System, waveform Bars.
- **Fade lengths:** Short (~20 ms) and Long (~200 ms).
- **Session order** lives in the library toolbar, not in Settings; **storage status line** at the bottom of the library.
- **One feature**, tasks grouped: Settings screen + meters first, then recording options, library, appearance.

## Open Questions
- None.
