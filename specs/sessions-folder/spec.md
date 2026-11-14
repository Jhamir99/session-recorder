# Spec: Sessions Folder

## Context and Goal
Sessions are saved in the app's own `Documents/Sessions` folder. On iPhone/iPad this folder belongs to the app: when the app is deleted, iOS deletes it and every session in it (the Mac keeps app data when the app is deleted). Users must be able to keep their sessions safe by choosing a folder outside the app (for example, a folder in "On My iPhone", iCloud Drive, or an external drive), be told clearly what happens if they don't, and quickly find a session's file from its detail.

## Users
- DJs/musicians who don't want to lose their recordings if they delete or reinstall the app, or who want sessions in a folder they already use (iCloud Drive, an external drive, a Music folder on Mac).

## User Stories
- As a user, I want to choose where my sessions are saved, so they are not deleted with the app.
- As a user, I want to be warned that sessions in the app folder are deleted with the app, so I can choose another folder in time.
- As a user, I want my existing sessions to come with me when I choose a new folder.
- As a user, I want recording to keep working even if my chosen folder is not available (drive unplugged, iCloud offline), without losing anything.
- As a user, I want to open a session's location in Files (iPhone/iPad) or Finder (Mac) from its detail.

## Functional Requirements

### RF-1: Sessions folder setting
- Settings (Library section) shall show the current sessions folder: **App Folder** (default) or the name of the chosen folder.
- **Choose Folder…** shall open the system folder picker; the user can pick any folder the system allows (On My iPhone/iPad, iCloud Drive, other providers, external drives; on Mac any folder they can write to).
- **Use App Folder** shall switch back to the app's own folder.
- The choice shall be remembered across launches; access to the chosen folder shall keep working after restarts without asking again (as long as the folder exists and the system allows it).

### RF-2: Warning about the app folder
- On iPhone/iPad, while the sessions folder is the App Folder, Settings shall show a warning under the option: "Sessions in the App Folder are deleted if you delete the app. Choose another folder to keep them."
- The warning shall not be shown when another folder is chosen, nor on Mac (the Mac keeps app data when the app is deleted).

### RF-3: Moving existing sessions
- When the user chooses a new folder (or goes back to the App Folder) and sessions exist in the current one, the system shall ask whether to **Move Sessions** to the new folder or **Keep Them** where they are.
- **Move Sessions** shall move every session file, with progress, without losing or duplicating any; if a name already exists in the new folder, the moved session gets a unique name (recording RF-6 rule).
- If moving fails part-way (for example, the destination is full), already-moved sessions stay in the new folder, the rest stay in the old one, and the user is told how many could not be moved.
- **Keep Them:** sessions in the old folder are no longer listed (they remain on disk; the user can move them later or switch back).

### RF-4: Using the chosen folder
- The library (session-library RF-1) shall list, play, rename, delete, trim and share sessions in the chosen folder exactly as in the App Folder.
- New and recovered recordings shall be saved to the chosen folder; the recording in progress stays in the app's private storage until it stops (recording plan), so an unavailable folder never interrupts a recording.
- Delete: in a chosen folder, deleting follows the system's rules for that location (Mac: moved to the Trash when possible; iPhone/iPad: deleted, or moved to "Recently Deleted" where the provider supports it); the confirmation text says which.

### RF-5: Folder not available
- If the chosen folder cannot be accessed (removed, renamed, drive disconnected, permission lost, provider offline), the library shall show a notice "The sessions folder isn't available." with **Choose Folder…** and **Use App Folder**.
- A recording that stops while the folder is not available shall be saved in the App Folder, with a notice saying where it was saved; nothing is lost.
- When the folder becomes available again, the library shows its sessions again.

### RF-6: Show the session's file
- The session detail (actions menu) shall offer **Show in Finder** on Mac (already available), which opens Finder with the file selected.
- On iPhone/iPad it shall offer **Show in Files**, which opens the system file browser inside the app, already at the session's folder (any location the app can access: App Folder, On My iPhone/iPad, iCloud Drive, external drives). From there the user can see, copy, move or share files as in the Files app. iOS has no supported way to open the Files app itself at an arbitrary location.

## Non-Functional Requirements
- **NFR-1:** Works on iPhone, iPad and Mac; only Apple frameworks (system folder picker, file coordination where needed); no backend.
- **NFR-2:** No recorded audio is ever lost when choosing, switching or losing access to a folder (recording NFR-4, session-library NFR-4).
- **NFR-3:** Persisted data: only the folder choice (a system access bookmark), no personal data.
- **NFR-4:** Listing and moving large folders stays responsive (work off the main thread, progress for moves).
- **NFR-5:** User-facing text in English and Spanish.

## Edge Cases
- Choosing the same folder again: no change.
- Choosing a folder inside the app's own storage: treated as the App Folder (no warning removal).
- Chosen folder contains non-CAF files: ignored (session-library RF-1).
- Chosen folder on iCloud Drive with files not downloaded yet: listed; playing/sharing downloads them first or explains that they are not available offline.
- External drive unplugged while the Sessions tab is open: notice appears; recording still works (RF-5).
- App deleted and reinstalled with sessions in a chosen folder: the folder is not remembered after reinstall (system behavior); the user chooses it again and the sessions appear.
- Moving a 4 GB session to a slow drive: progress shown; the app can be used meanwhile, but recording to that folder waits until moving ends (or saves to App Folder).

## Out of Scope
- Syncing between devices beyond what the chosen provider (e.g. iCloud Drive) does by itself.
- Several folders at the same time, sub-folders inside the sessions folder.
- Importing audio files that were not recorded by the app.

## Completion Criteria
- The folder can be chosen, remembered after restart, and switched back to the App Folder (RF-1).
- The App Folder warning shows on iPhone/iPad only while the App Folder is used (RF-2).
- Existing sessions can be moved with progress, or kept, without loss (RF-3).
- Library and recording work with a chosen folder, including iCloud Drive and an external drive (RF-4).
- An unavailable folder shows the notice and recordings fall back to the App Folder (RF-5).
- Show in Files / Show in Finder work from the detail (RF-6).
- After deleting and reinstalling the app on iPhone, sessions in a chosen folder are still there and appear after choosing the folder again.

## Decisions (approved 2026-11-14)
- **Moving:** ask Move Sessions / Keep Them every time the folder changes and sessions exist.
- **Warning:** only in Settings (iPhone/iPad, while the App Folder is used).
- **Show in Files:** in-app system file browser at the session's folder (works for every location); Mac keeps Show in Finder.

## Open Questions
- None.
