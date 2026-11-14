# Spec: Session Library

## Context and Goal
The `recording` feature saves each session as one `.caf` file (uncompressed PCM) in a `Sessions` folder inside the app's Documents folder, named `Session YYYY-MM-DD HH.mm`. The Sessions tab currently shows only an empty state and the `REC` indicator. This feature turns it into the session library: list sessions, play them back with a waveform, rename, delete, trim (saving a new copy), and share/export them in the format the user chooses. Sessions also become visible in Files (iPhone/iPad) and reachable from Finder (Mac).

## Users
- DJs/musicians who recorded sessions with the app and want to listen to them, keep the good ones, cut the start/end, and send or archive them.

## User Stories
- As a user, I want to see all my sessions with their name, date and duration so I can find the one I want.
- As a user, I want to play a session and jump to any point of it using its waveform.
- As a user, I want to rename a session so I can recognize it later (e.g., "Friday warm-up").
- As a user, I want to delete sessions I do not need, without deleting one by accident.
- As a user, I want to cut silence or mistakes at the start and end of a session without losing the original.
- As a user, I want to share or export a session in a format that fits (lossless or compressed), knowing how big the file will be.
- As a user, I want to see my sessions in the Files app / Finder to back them up or move them.
- As a Mac user, I want keyboard shortcuts for playback and deleting.

## Functional Requirements

### RF-1: Session list
- The Sessions tab shall list every session in the `Sessions` folder, newest first, showing name, recording date and time, and duration.
- The list shall update when a recording is saved or recovered (recording RF-6/RF-8), and when sessions are renamed, deleted or trimmed in the app.
- When the app becomes active, the list shall reflect changes made outside the app (for example, a session renamed or deleted in Files/Finder).
- Only `.caf` files shall be listed; other files in the folder shall be ignored. A file that cannot be read shall be listed with its name and a "Can't be played" state instead of being hidden.
- When there are no sessions, the existing empty state shall be shown ("No sessions yet").
- While recording or paused, the `REC`/`PAUSED` indicator (recording RF-4) shall stay visible above the list. The recording in progress shall not appear in the list until it is saved.

### RF-2: Session detail and playback
- Selecting a session shall open its detail: name, date and time, duration, format (for example, `Stereo · 24-bit/48 kHz`), file size, waveform, and player controls.
- The player shall offer play/pause, a playback position on the waveform that can be dragged or tapped to seek, skip back/forward 15 seconds, and elapsed/total time.
- The waveform shall show the whole session; for long sessions (for example, 4 h) it shall appear progressively or with a loading indicator and the player shall be usable before it is complete.
- The waveform shall be kept in a small cache in the app's Caches folder, so a session opens instantly the next time. The cache is not user data: if it is missing (the system may clear Caches) or outdated (the session file changed), it shall be computed again.
- Playback shall continue when the app goes to the background or the device is locked (iPhone/iPad), and shall show the session name in the system's Now Playing controls (lock screen / Control Center).
- Playback shall stop when the user leaves the detail, opens another session, or starts a recording.
- While a recording exists (recording or paused), playback shall be disabled with a short explanation, so that playback never affects the recording.

### RF-3: Rename
- The user shall be able to rename a session from the list (swipe/context action) and from the detail.
- The name shall be trimmed of leading/trailing spaces; an empty name shall not be accepted.
- Characters not allowed in file names (`/` and `:`) shall not be accepted, with a short explanation.
- If another session already has the name, the system shall not rename it and shall explain why.
- Renaming shall rename the file (the session name is the file name) and keep the recording date shown in the list.

### RF-4: Delete
- The user shall be able to delete a session from the list (swipe/context action, Mac: ⌘⌫) and from the detail.
- Deleting shall always ask for confirmation, naming the session.
- On Mac, deleting shall move the session file to the system **Trash** (it can be restored from Finder). On iPhone/iPad, where apps have no system Trash for their files, deleting shall remove the file permanently, and the confirmation shall say so.
- After deleting, the session shall disappear from the list; if its detail was open, the app shall return to the list.
- A session that is playing shall stop before it is deleted.

### RF-5: Trim
- From the detail, the user shall be able to trim a session by dragging start and end handles on the waveform.
- While trimming, the system shall show the exact start and end times and the resulting duration, and allow playing the selected range.
- The resulting duration shall be at least 1 second.
- Saving shall create a **new session** with only the selected range, in the same format as the original (bit-exact samples, no re-encoding), named after the original with ` (trimmed)` (made unique like recording RF-6, e.g. ` (trimmed 2)`). The original shall be kept unchanged.
- The new session shall keep the original's recording date plus the trim start offset, appear in the list, and open in the detail.
- If there is not enough free storage for the new file, the system shall not start saving and shall explain why.

### RF-6: Share and export
- From the detail and the list (context action), the user shall be able to share a session through one flow:
  1. choose a format: **Original (CAF)**, **WAV**, **AIFF**, **FLAC**, **Apple Lossless (ALAC)**, or **AAC (M4A)** with a bitrate of 128, 192, 256 or 320 kbps;
  2. see the estimated file size for the chosen format;
  3. hand the file to the system share sheet (AirDrop, Files/Save to Files, Mail, other apps; on Mac, the Mac share menu and "Save to…").
- Lossless formats shall keep the session's sample rate, bit depth and channels. AAC shall keep the sample rate when supported by the encoder (otherwise 48 kHz or 44.1 kHz).
- Exporting shall show progress and can be cancelled; it shall not modify the session.
- Exported files shall be named after the session (for example, `Friday warm-up.flac`) and shall be temporary: they are removed after sharing finishes or is cancelled, and never appear in the library.
- The last chosen format and bitrate shall be remembered for the next share.
- If the export fails (for example, not enough storage), the system shall show a short error and remove the partial file.

### RF-7: Files and Finder visibility
- On iPhone/iPad, the app's Documents folder shall be visible in the Files app ("On My iPhone/iPad › Session Recorder"), so the `Sessions` folder can be browsed, copied and backed up.
- On Mac, the detail shall offer **Show in Finder**, which reveals the session file.
- Only the `Sessions` folder and finished sessions shall be visible; recordings in progress stay in the app's private storage (recording plan).

### RF-8: Mac keyboard shortcuts and menu
- On Mac, the system shall provide: Space to play/pause in the detail (when no recording exists and no text field has focus), ⌘⌫ to delete the selected session (with confirmation), Return or a context action to rename, and ⌘← / ⌘→ to skip back/forward 15 seconds.
- Space shall control playback only when no recording exists; while recording or paused it keeps controlling the recording (recording RF-9).
- On iPad with a hardware keyboard, the same shortcuts should work where the platform supports them.

## Non-Functional Requirements
- **NFR-1:** Works on iPhone, iPad and Mac with platform-appropriate presentation (list + detail navigation on iPhone, split view on iPad/Mac); usable at large Dynamic Type sizes.
- **NFR-2:** Opening the library and scrolling stays smooth with at least 200 sessions; reading durations and waveforms never blocks the UI.
- **NFR-3:** Sessions of several hours (at least 4 h, about 4 GB) can be played, trimmed and exported without memory growing with the file size.
- **NFR-4:** No operation in this feature ever modifies or loses the original audio except an explicit, confirmed delete (to the Trash on Mac). Trim and export write new files; a failed or cancelled operation leaves no partial files.
- **NFR-5:** Only Apple frameworks; no backend or external services. Persisted settings contain no personal data (format/bitrate choice only). The waveform cache contains only waveform data and lives in Caches (removable by the system at any time).
- **NFR-6:** User-facing text in English and understandable to non-technical users.

## Edge Cases
- Session renamed or deleted in Files/Finder while the app is in the background: the list reflects it when the app becomes active; an open detail of a deleted session returns to the list (RF-1).
- A non-CAF file is copied into the `Sessions` folder in Files: it is not listed (RF-1).
- A damaged/unreadable `.caf`: listed with "Can't be played"; rename, delete and Show in Finder still work; play, trim and share (except Original) are disabled (RF-1).
- Recording saved while the Sessions tab is open: it appears at the top of the list (RF-1).
- User tries to play while a recording exists: playback disabled with explanation (RF-2).
- A call or another app interrupts playback (iPhone/iPad): playback pauses and does not resume automatically.
- Rename to a name that differs only by upper/lower case from another session: treated as the same name (file systems are case-insensitive by default) (RF-3).
- Trim with start = end or less than 1 s: Save disabled (RF-5).
- Export of a mono session: exported as mono (RF-6).
- AAC export of a 96 kHz session: exported at 48 kHz (RF-6).
- Not enough storage for trim/export: error before starting, no partial file (RF-5, RF-6).
- The session being shared is deleted or renamed afterwards: the shared copy is unaffected (RF-6).

## Out of Scope
- Notes, tags, markers, favorites, search, sorting options and folders.
- Editing other than start/end trim (cuts in the middle, fades, normalization, gain).
- MP3 export (no Apple encoder) and other formats not listed in RF-6.
- iCloud sync, cloud upload, accounts.
- Importing audio files from outside the app into the library (they are ignored if copied into the folder).
- Undo for delete / a trash inside the app (the Mac uses the system Trash).
- Spectrum view or level analysis.

## Completion Criteria
- The Sessions tab lists sessions newest first with name, date and duration, and stays in sync with saved recordings and with changes made in Files/Finder (RF-1).
- The detail shows info, waveform and a working player with seek and ±15 s; playback continues in the background with Now Playing info, and is disabled while recording (RF-2).
- Rename and delete work from list and detail with validation and confirmation (RF-3, RF-4).
- Trim creates a new, bit-exact session for the selected range and keeps the original (RF-5).
- Share/export produces correct files in every format in RF-6 (checked by opening them in another app), shows size estimate and progress, and leaves no temporary files behind (RF-6).
- Sessions are visible in Files on iPhone/iPad; Show in Finder works on Mac (RF-7).
- Mac shortcuts work as defined and do not interfere with recording shortcuts (RF-8).
- Verified on a real iPhone and Mac with short sessions and a ≥ 1 h session.

## Decisions (approved 2026-11-14)
- **Waveform cache:** small cache per session in the app's Caches folder, regenerated when missing or outdated (RF-2).
- **Delete:** Mac moves the file to the system Trash; iPhone/iPad delete permanently after confirmation (RF-4).
- **Background playback and Now Playing:** included (RF-2).
- **Feature size:** one feature, including share/export; tasks ordered list → playback → rename/delete → trim → export.

## Open Questions
- None.
