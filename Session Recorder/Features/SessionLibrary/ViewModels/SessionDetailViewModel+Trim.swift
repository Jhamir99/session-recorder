import Foundation

/// Trim mode (RF-5): drag start/end on the waveform, preview the range, save it as a new session.
extension SessionDetailViewModel {
    var isTrimming: Bool { trimRange != nil }

    /// Space / media play-pause: the selection while trimming, otherwise the whole session (RF-8).
    func togglePlaybackFromKeyboard() {
        if isPlaying {
            pause()
        } else if isTrimming {
            playSelection()
        } else {
            play()
        }
    }

    var canSaveTrim: Bool {
        guard let trimRange, !isSavingTrim else { return false }
        return SessionLibraryLogic.isValidTrim(trimRange, duration: duration)
    }

    func startTrim() {
        guard duration > 0, !session.isUnreadable else { return }
        pause()
        trimRange = TrimRange(start: 0, end: duration)
    }

    func cancelTrim() {
        pause()
        player.clearRangeEnd()
        trimRange = nil
    }

    func setTrimStart(_ time: TimeInterval) {
        guard let trimRange else { return }
        self.trimRange = SessionLibraryLogic.clampedTrimRange(TrimRange(start: min(time, trimRange.end), end: trimRange.end), duration: duration)
        followRangeWhilePlaying()
    }

    func setTrimEnd(_ time: TimeInterval) {
        guard let trimRange else { return }
        self.trimRange = SessionLibraryLogic.clampedTrimRange(TrimRange(start: trimRange.start, end: max(time, trimRange.start)), duration: duration)
        followRangeWhilePlaying()
    }

    /// While the selection plays, moving a handle updates where playback stops; if the playhead ends up
    /// outside the selection, playback jumps to the new start.
    private func followRangeWhilePlaying() {
        guard isPlaying, let trimRange else { return }
        let time = player.currentTime
        if time < trimRange.start || time >= trimRange.end {
            player.playRange(from: trimRange.start, to: trimRange.end)
        } else {
            player.setRangeEnd(trimRange.end)
        }
    }

    /// Plays only the selected range (stops at its end).
    func playSelection() {
        guard let trimRange else { return }
        if isPlaying { pause() }
        startPlayback { $0.playRange(from: trimRange.start, to: trimRange.end) }
    }

    /// Writes the range to a new session (the original is kept) and asks the library to open it.
    func saveTrim() {
        guard canSaveTrim, let trimRange else { return }
        pause()
        player.clearRangeEnd()
        isSavingTrim = true
        let url = session.url
        let name = SessionLibraryLogic.trimmedName(for: session.name, existingNames: trimContext.existingNames())
        let date = SessionLibraryLogic.trimmedRecordedDate(originalDate: session.recordedDate, range: trimRange)
        let context = trimContext
        Task { [weak self] in
            do {
                let newURL = try await Task.detached(priority: .userInitiated) {
                    try SessionLibraryStore().trim(url, range: trimRange, newName: name, recordedDate: date)
                }.value
                self?.isSavingTrim = false
                self?.trimRange = nil
                context.didSave(newURL)
            } catch {
                self?.isSavingTrim = false
                self?.trimErrorMessage = (error as? SessionLibraryStore.TrimError) == .notEnoughStorage
                    ? LibraryNotice(kind: .notEnoughStorage).text
                    : LibraryNotice(kind: .operationFailed(message: String(localized: "The trimmed session could not be saved. Please try again.", comment: "Trim error"))).text
            }
        }
    }
}
