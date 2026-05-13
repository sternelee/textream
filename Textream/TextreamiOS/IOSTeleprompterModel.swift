import SwiftUI

@Observable
final class IOSTeleprompterModel {
    var document = ScriptDocument()
    var session = ReadingSessionState(mode: .classic)
    var audioMonitor = IOSAudioMonitor()
    var wordTracker = IOSWordTrackingRecognizer()
    var documentLibrary = IOSDocumentLibrary()

    var selectedMode: TeleprompterMode = .classic {
        didSet {
            handleSelectedModeChange(from: oldValue, to: selectedMode)
        }
    }
    var isReaderPresented = false
    var scrollSpeedWordsPerSecond: Double = 2.0
    var readerFontSize: Double = 30
    var pageTitle: String = "Untitled"
    var currentDocumentURL: URL?
    var documentStatusMessage: String?
    var presentedErrorMessage: String?

    var currentWords: [String] {
        TextSegmentation.splitIntoWords(document.currentPageText)
    }

    var currentCollapsedText: String {
        currentWords.joined(separator: " ")
    }

    var currentWordIndex: Int {
        guard !currentWords.isEmpty else { return 0 }
        switch session.mode {
        case .wordTracking:
            return wordIndex(forRecognizedCharCount: session.recognizedCharCount)
        case .classic, .voiceActivated:
            return min(max(Int(session.wordProgress), 0), max(currentWords.count - 1, 0))
        }
    }

    var progressRatio: Double {
        switch session.mode {
        case .wordTracking:
            guard !currentCollapsedText.isEmpty else { return 0 }
            return min(max(Double(session.recognizedCharCount) / Double(max(currentCollapsedText.count, 1)), 0), 1)
        case .classic, .voiceActivated:
            guard !currentWords.isEmpty else { return 0 }
            return min(max(session.wordProgress / Double(max(currentWords.count, 1)), 0), 1)
        }
    }

    var modeSupportDescription: String {
        switch selectedMode {
        case .classic:
            return "Classic mode scrolls continuously at the chosen speed."
        case .voiceActivated:
            return "Voice-Activated mode only advances while speech is detected."
        case .wordTracking:
            return "Word Tracking mode advances from live speech recognition and fuzzy text matching."
        }
    }

    var readerStatusMessage: String? {
        if let runtimeErrorMessage {
            return runtimeErrorMessage
        }
        switch session.mode {
        case .classic:
            return "Classic mode scrolls continuously at a fixed speed."
        case .voiceActivated:
            if !session.isListening {
                return "Microphone is paused. Resume it to continue voice-activated scrolling."
            }
            return audioMonitor.isSpeaking ? "Speaking detected — scrolling." : "Waiting for speech…"
        case .wordTracking:
            if !session.isListening {
                return "Microphone is paused. Resume it to continue Word Tracking."
            }
            if !session.lastSpokenText.isEmpty {
                return "Heard: \(session.lastSpokenText)"
            }
            return "Listening for speech to advance the script…"
        }
    }

    var runtimeErrorMessage: String? {
        if let error = wordTracker.errorMessage, !error.isEmpty { return error }
        if let error = audioMonitor.errorMessage, !error.isEmpty { return error }
        if let error = documentLibrary.errorMessage, !error.isEmpty { return error }
        return nil
    }

    var currentDocumentDisplayName: String {
        currentDocumentURL?.deletingPathExtension().lastPathComponent ?? normalizedTitle
    }

    init() {
        document = ScriptDocument(
            title: "Untitled",
            pages: [
                "Welcome to Textream for iPhone and iPad. This MVP focuses on the core teleprompter experience. Use the page controls below to move between pages, change modes, and start reading.",
                "Classic mode is implemented first. Voice-Activated and Word Tracking will be connected in the next iterations of the Ralph loop."
            ]
        )
        pageTitle = document.title
        refreshDocuments()
    }

    func updateCurrentPageText(_ text: String) {
        document.setCurrentPageText(text)
        documentStatusMessage = nil
        clearRuntimeErrors()
    }

    func addPage() {
        document.addPage(after: document.currentPageIndex)
        documentStatusMessage = nil
    }

    func removeCurrentPage() {
        document.removePage(at: document.currentPageIndex)
        documentStatusMessage = nil
    }

    func jumpToPage(_ index: Int) {
        _ = document.jump(to: index)
        restoreSessionForCurrentPage(restartEngines: isReaderPresented)
        documentStatusMessage = nil
    }

    func startReading() {
        guard document.hasAnyContent else {
            presentError("Add some script text before starting the teleprompter.")
            return
        }
        document.title = normalizedTitle
        document.markCurrentPageRead()
        session = ReadingSessionState(mode: selectedMode, isRunning: true, isPaused: false)
        isReaderPresented = true
        restoreSessionForCurrentPage(restartEngines: true)
    }

    func stopReading() {
        audioMonitor.stop()
        wordTracker.stop()
        session.stop()
        isReaderPresented = false
        clearRuntimeErrors()
    }

    func togglePause() {
        session.togglePause()
        if session.isPaused {
            documentStatusMessage = "Paused \(session.mode.label)."
        } else {
            documentStatusMessage = "Resumed \(session.mode.label)."
        }
    }

    func toggleListening() {
        clearRuntimeErrors()
        switch session.mode {
        case .classic:
            return
        case .voiceActivated:
            if session.isListening {
                audioMonitor.stop()
                session.updateAudio(audioLevels: audioMonitor.audioLevels, isListening: false)
            } else {
                audioMonitor.start()
                session.updateAudio(audioLevels: audioMonitor.audioLevels, isListening: audioMonitor.isRunning)
            }
        case .wordTracking:
            if session.isListening {
                wordTracker.stop()
                session.updateSpeech(
                    charCount: wordTracker.recognizedCharCount,
                    lastSpokenText: wordTracker.lastSpokenText,
                    audioLevels: wordTracker.audioLevels,
                    isListening: false
                )
            } else {
                wordTracker.start(with: document.currentPageText, preservingCharCount: session.recognizedCharCount)
                session.updateSpeech(
                    charCount: wordTracker.recognizedCharCount,
                    lastSpokenText: wordTracker.lastSpokenText,
                    audioLevels: wordTracker.audioLevels,
                    isListening: wordTracker.isListening
                )
            }
        }
    }

    func tick(deltaSeconds: Double) {
        consumeSubsystemErrors()
        switch session.mode {
        case .classic:
            session.updateAudio(audioLevels: [], isListening: false)
            session.applyClassicProgress(
                deltaWords: scrollSpeedWordsPerSecond * deltaSeconds,
                totalWordCount: currentWords.count
            )
        case .voiceActivated:
            session.updateAudio(audioLevels: audioMonitor.audioLevels, isListening: audioMonitor.isRunning)
            guard audioMonitor.isSpeaking else { return }
            session.applyClassicProgress(
                deltaWords: scrollSpeedWordsPerSecond * deltaSeconds,
                totalWordCount: currentWords.count
            )
        case .wordTracking:
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: wordTracker.audioLevels,
                isListening: wordTracker.isListening
            )
        }
    }

    func setWordProgress(_ progress: Double) {
        let upperBound = Double(max(currentWords.count, 0))
        session.wordProgress = min(max(0, progress), upperBound)
        clearRuntimeErrors()
    }

    func jumpToWord(index: Int) {
        switch session.mode {
        case .wordTracking:
            wordTracker.jumpTo(wordIndex: index, in: currentWords)
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: wordTracker.audioLevels,
                isListening: wordTracker.isListening
            )
        case .classic, .voiceActivated:
            setWordProgress(Double(index))
        }
    }

    func goToNextPage() {
        guard let next = document.nextReadablePageIndex() else { return }
        _ = document.jump(to: next)
        document.markCurrentPageRead()
        session.resetProgressForNewPage()
        session.start(mode: selectedMode)
        syncAudioMonitoringForCurrentMode()
    }

    func goToPreviousPage() {
        guard let previous = document.previousReadablePageIndex() else { return }
        _ = document.jump(to: previous)
        session.resetProgressForNewPage()
        session.start(mode: selectedMode)
        syncAudioMonitoringForCurrentMode()
    }

    func newDocument() {
        stopReading()
        document = ScriptDocument(title: "Untitled", pages: [""])
        pageTitle = document.title
        currentDocumentURL = nil
        documentStatusMessage = "Started a new script."
        clearRuntimeErrors()
    }

    func saveDocument() {
        do {
            document.title = normalizedTitle
            let savedURL = try documentLibrary.save(
                document: document,
                preferredTitle: normalizedTitle,
                currentURL: currentDocumentURL
            )
            currentDocumentURL = savedURL
            pageTitle = savedURL.deletingPathExtension().lastPathComponent
            document.title = pageTitle
            documentStatusMessage = "Saved to \(pageTitle).textream"
        } catch {
            documentStatusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func loadDocument(_ item: SavedScriptDocument) {
        do {
            stopReading()
            let loaded = try documentLibrary.load(item)
            document = loaded
            currentDocumentURL = item.url
            pageTitle = item.title
            document.title = item.title
            documentStatusMessage = "Opened \(item.title).textream"
        } catch {
            documentStatusMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    func deleteDocument(_ item: SavedScriptDocument) {
        do {
            try documentLibrary.delete(item)
            if currentDocumentURL == item.url {
                newDocument()
            } else {
                documentStatusMessage = "Deleted \(item.title).textream"
            }
        } catch {
            documentStatusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func refreshDocuments() {
        documentLibrary.refresh()
        if let error = documentLibrary.errorMessage {
            presentError(error)
        }
    }

    func dismissPresentedError() {
        presentedErrorMessage = nil
    }

    private var normalizedTitle: String {
        let trimmed = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func syncAudioMonitoringForCurrentMode() {
        switch session.mode {
        case .classic:
            audioMonitor.stop()
            wordTracker.stop()
            session.updateAudio(audioLevels: [], isListening: false)
        case .voiceActivated:
            wordTracker.stop()
            audioMonitor.start()
            session.updateAudio(audioLevels: audioMonitor.audioLevels, isListening: audioMonitor.isRunning)
        case .wordTracking:
            audioMonitor.stop()
            wordTracker.start(with: document.currentPageText)
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: wordTracker.audioLevels,
                isListening: wordTracker.isListening
            )
        }
    }

    private func wordIndex(forRecognizedCharCount charCount: Int) -> Int {
        guard !currentWords.isEmpty else { return 0 }
        var offset = 0
        for (index, word) in currentWords.enumerated() {
            let end = offset + word.count
            if charCount <= end {
                return index
            }
            offset = end + 1
        }
        return max(currentWords.count - 1, 0)
    }

    private func handleSelectedModeChange(from oldMode: TeleprompterMode, to newMode: TeleprompterMode) {
        guard oldMode != newMode else { return }
        documentStatusMessage = "Mode switched to \(newMode.label)."
        clearRuntimeErrors()
        if isReaderPresented {
            session.start(mode: newMode)
            restoreSessionForCurrentPage(restartEngines: true)
        }
    }

    private func restoreSessionForCurrentPage(restartEngines: Bool) {
        session.resetProgressForNewPage()
        session.start(mode: selectedMode)
        if restartEngines {
            syncAudioMonitoringForCurrentMode()
        }
    }

    private func consumeSubsystemErrors() {
        if let error = runtimeErrorMessage {
            presentError(error)
        }
    }

    private func clearRuntimeErrors() {
        audioMonitor.errorMessage = nil
        wordTracker.errorMessage = nil
    }

    private func presentError(_ message: String) {
        presentedErrorMessage = message
        documentStatusMessage = message
    }
}
