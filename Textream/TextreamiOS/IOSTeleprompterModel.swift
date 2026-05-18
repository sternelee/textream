import AVFoundation
import SwiftUI

@Observable
final class IOSTeleprompterModel {
    var document = ScriptDocument() {
        didSet { persistDraftIfNeeded() }
    }
    var session = ReadingSessionState(mode: .classic)
    var audioMonitor = IOSAudioMonitor()
    var wordTracker = IOSWordTrackingRecognizer()
    var documentLibrary = IOSDocumentLibrary()

    var selectedMode: TeleprompterMode = .classic {
        didSet {
            guard oldValue != selectedMode else { return }
            handleSelectedModeChange(from: oldValue, to: selectedMode)
            persistReaderSettingsIfNeeded()
        }
    }
    var isReaderPresented = false
    var scrollSpeedWordsPerSecond: Double = 2.0 {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var readerFontSize: Double = IOSReaderFontSizing.default {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var readerLineSpacing: Double = 1.2 {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var keepScreenAwakeWhileReading: Bool = true {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var hapticEnabled: Bool = true {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var mirrorModeEnabled: Bool = false {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var forceDarkMode: Bool = true {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var readerFontFamily: IOSReaderFontFamily = .rounded {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var highlightColorPreset: IOSHighlightColorPreset = .amber {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var speechLocale: IOSSpeechLocaleOption = .system {
        didSet {
            persistReaderSettingsIfNeeded()
            UserDefaults.standard.set(speechLocale.localeIdentifier, forKey: "speechLocale")
            guard isReaderPresented, session.mode == .wordTracking else { return }
            startWordTrackingRecognizer(preservingCharCount: session.recognizedCharCount)
            syncWordTrackingSessionFromRecognizer()
        }
    }
    var phoneticTooltipEnabled: Bool = true {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var nativeLanguage: String = "zh" {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var phoneticSource: PhoneticSource = .localDictionary {
        didSet { persistReaderSettingsIfNeeded() }
    }
    var pageTitle: String = "Untitled" {
        didSet { persistDraftIfNeeded() }
    }
    var currentDocumentURL: URL? {
        didSet { persistDraftIfNeeded() }
    }
    var documentStatusMessage: String?
    var presentedErrorMessage: String?
    var launchRecoveryMessage: String?
    var exportDocumentURL: URL? = nil
    var isExportSheetPresented = false
    var reachedEndOfScript = false
    var lastAutoSavedAt: Date? = nil
    private var voiceActivatedSilentSeconds: Double = 0
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let defaults = UserDefaults.standard
    private let readerSettingsKey = "dev.leeapp.textream.ios.reader-settings"
    private let draftStateKey = "dev.leeapp.textream.ios.draft-state"
    private var isRestoringPersistentState = false
    private var lastSavedSnapshot: IOSDraftState?
    private var hasAutoAdvancedCurrentPage = false
    private var readingStartTime: Date?

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

    var totalWordCount: Int {
        document.pages.reduce(into: 0) { partialResult, page in
            partialResult += TextSegmentation.splitIntoWords(page).count
        }
    }

    var totalCharCount: Int {
        document.pages.reduce(into: 0) { $0 += $1.count }
    }

    var estimatedReadingTime: String {
        let wordsPerMinute = 150.0
        let minutes = Double(totalWordCount) / wordsPerMinute
        if minutes < 1.0 {
            return "< 1 min"
        }
        return String(format: "%.0f min", minutes)
    }

    var estimatedTimeRemaining: String {
        let remainingCurrentPage = max(currentWords.count - Int(session.wordProgress), 0)
        var remainingWords = remainingCurrentPage
        for i in (document.currentPageIndex + 1)..<document.pages.count {
            remainingWords += TextSegmentation.splitIntoWords(document.pages[i]).count
        }
        guard remainingWords > 0, scrollSpeedWordsPerSecond > 0 else { return "0s" }
        let totalSeconds = Double(remainingWords) / scrollSpeedWordsPerSecond
        if totalSeconds < 60 {
            return String(format: "%.0fs", totalSeconds)
        }
        let minutes = Int(totalSeconds / 60)
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var modeSupportDescription: String {
        switch selectedMode {
        case .classic:
            return String(localized: "Classic mode auto-scrolls at a fixed pace so you can rehearse without using the microphone.")
        case .voiceActivated:
            return String(localized: "Voice-Activated mode advances only while the microphone hears speech, which helps you pause naturally.")
        case .wordTracking:
            return String(localized: "Word Tracking mode listens to your speech and keeps the highlighted word close to what you are actually saying.")
        }
    }

    var readerStatusMessage: String? {
        if let runtimeErrorMessage {
            return runtimeErrorMessage
        }
        if session.isPaused {
            switch session.mode {
            case .classic:
                return "Reader paused. Resume to continue auto-scrolling."
            case .voiceActivated:
                return "Voice-Activated mode is paused. Resume to continue listening."
            case .wordTracking:
                return "Word Tracking is paused. Resume to continue recognition from the current position."
            }
        }
        switch session.mode {
        case .classic:
            return "Classic mode keeps a steady pace based on your chosen scroll speed."
        case .voiceActivated:
            if audioMonitor.permissionDenied {
                return "Microphone permission is required before Voice-Activated mode can listen."
            }
            if !session.isListening {
                return "Microphone is paused. Turn it back on to continue voice-activated scrolling."
            }
            return audioMonitor.isSpeaking ? "Speaking detected — the teleprompter is moving." : "Listening for your voice…"
        case .wordTracking:
            if wordTracker.microphonePermissionDenied {
                return "Microphone permission is required for Word Tracking."
            }
            if wordTracker.speechPermissionDenied {
                return "Speech recognition permission is required for Word Tracking."
            }
            if !session.isListening {
                return "Microphone is paused. Turn it back on to resume Word Tracking."
            }
            if !session.lastSpokenText.isEmpty {
                return "Heard: \(session.lastSpokenText)"
            }
            return "Listening for speech in \(resolvedWordTrackingLocaleLabel) to move the highlight…"
        }
    }

    var runtimeErrorMessage: String? {
        if let error = wordTracker.errorMessage, !error.isEmpty { return error }
        if let error = audioMonitor.errorMessage, !error.isEmpty { return error }
        if let error = documentLibrary.errorMessage, !error.isEmpty { return error }
        return nil
    }

    var wordTrackingDebugMessage: String? {
        guard selectedMode == .wordTracking || session.mode == .wordTracking else { return nil }
        return wordTracker.trackingDebugSummary ?? wordTracker.trackingDebugMessage
    }

    var wordTrackingLocaleDisplayLabel: String {
        resolvedWordTrackingLocaleLabel
    }

    var currentDocumentDisplayName: String {
        currentDocumentURL?.deletingPathExtension().lastPathComponent ?? normalizedTitle
    }

    var hasUnsavedChanges: Bool {
        if currentDocumentURL == nil {
            return document.hasAnyContent || normalizedTitle != "Untitled"
        }
        guard let lastSavedSnapshot else { return true }
        return !hasSameSaveContent(as: lastSavedSnapshot)
    }

    var currentDocumentStatusLabel: String {
        if currentDocumentURL == nil {
            return hasUnsavedChanges ? "Draft" : "New"
        }
        return hasUnsavedChanges ? "Unsaved" : "Saved"
    }

    var currentPageWordCount: Int {
        TextSegmentation.splitIntoWords(document.currentPageText).count
    }

    var currentPageCharCount: Int {
        document.currentPageText.count
    }

    var elapsedReadingTimeFormatted: String {
        guard let start = readingStartTime else { return "00:00" }
        let elapsed = Date().timeIntervalSince(start)
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var sampleScripts: [IOSTeleprompterSample] {
        IOSTeleprompterSample.allCases
    }

    init() {
        loadPersistedState()
        refreshDocuments()
    }

    func updateCurrentPageText(_ text: String) {
        let maxPageLength = 50000
        let trimmed = text.count > maxPageLength ? String(text.prefix(maxPageLength)) : text
        document.setCurrentPageText(trimmed)
        if isReaderPresented, session.mode == .wordTracking {
            wordTracker.updateText(document.currentPageText)
            syncWordTrackingSessionFromRecognizer()
        }
        documentStatusMessage = nil
        clearRuntimeErrors()
        persistDraft()
    }

    func addPage() {
        document.addPage(after: document.currentPageIndex)
        documentStatusMessage = "Added page \(document.currentPageIndex + 1)."
        persistDraft()
    }

    func removeCurrentPage() {
        let removedPage = document.currentPageIndex + 1
        document.removePage(at: document.currentPageIndex)
        documentStatusMessage = "Removed page \(removedPage)."
        persistDraft()
    }

    func jumpToPage(_ index: Int) {
        _ = document.jump(to: index)
        restoreSessionForCurrentPage(restartEngines: isReaderPresented)
        documentStatusMessage = nil
        reachedEndOfScript = false
        persistDraft()
    }

    func startReading() {
        guard document.hasAnyContent else {
            presentError("Add some script text before starting the teleprompter.")
            return
        }
        moveToReadableStartPageIfNeeded()
        if document.lastReadPageIndex >= 0 && document.lastReadPageIndex < document.pages.count {
            document.currentPageIndex = document.lastReadPageIndex
        }
        document.title = normalizedTitle
        document.markCurrentPageRead()
        session = ReadingSessionState(mode: selectedMode, isRunning: true, isPaused: false)
        isReaderPresented = true
        hasAutoAdvancedCurrentPage = false
        readingStartTime = Date()
        reachedEndOfScript = false
        restoreSessionForCurrentPage(restartEngines: true)
        if document.lastReadWordIndex > 0 {
            let target = min(document.lastReadWordIndex, max(currentWords.count - 1, 0))
            if target > 0 {
                jumpToWord(index: target)
            }
        }
        if keepScreenAwakeWhileReading {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        triggerHaptic(style: .impact)
        persistDraft()
    }

    func stopReading() {
        document.lastReadPageIndex = document.currentPageIndex
        document.lastReadWordIndex = currentWordIndex
        audioMonitor.stop()
        wordTracker.stop()
        session.stop()
        isReaderPresented = false
        readingStartTime = nil
        reachedEndOfScript = false
        UIApplication.shared.isIdleTimerDisabled = false
        clearRuntimeErrors()
        persistDraft()
    }

    func togglePause() {
        session.togglePause()
        if session.isPaused {
            pauseActiveInputsForCurrentMode()
            documentStatusMessage = "Paused \(session.mode.label)."
        } else {
            resumeActiveInputsForCurrentMode()
            documentStatusMessage = "Resumed \(session.mode.label)."
        }
        persistDraft()
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
                startWordTrackingRecognizer(preservingCharCount: session.recognizedCharCount)
                syncWordTrackingSessionFromRecognizer()
            }
        }
        persistDraft()
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
            if audioMonitor.isSpeaking, !currentWords.isEmpty {
                voiceActivatedSilentSeconds = 0
                let level = audioMonitor.averageLevel
                let speedMultiplier = 0.5 + Double(min(level, 1.0)) * 3.0
                let clampedMultiplier = min(max(speedMultiplier, 0.3), 2.5)
                session.applyClassicProgress(
                    deltaWords: scrollSpeedWordsPerSecond * clampedMultiplier * deltaSeconds,
                    totalWordCount: currentWords.count
                )
            } else {
                voiceActivatedSilentSeconds += deltaSeconds
                if voiceActivatedSilentSeconds >= 5.0, !session.isPaused {
                    togglePause()
                    voiceActivatedSilentSeconds = 0
                }
            }
        case .wordTracking:
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: wordTracker.audioLevels,
                isListening: wordTracker.isListening
            )
        }
        handleAutomaticPageCompletionIfNeeded()
    }

    func setWordProgress(_ progress: Double) {
        let upperBound = Double(max(currentWords.count, 0))
        session.wordProgress = min(max(0, progress), upperBound)
        clearRuntimeErrors()
        persistDraft()
    }

    func jumpToWord(index: Int) {
        switch session.mode {
        case .wordTracking:
            wordTracker.jumpTo(wordIndex: index, in: currentWords)
            if session.isListening {
                startWordTrackingRecognizer(preservingCharCount: wordTracker.recognizedCharCount)
            }
            syncWordTrackingSessionFromRecognizer()
        case .classic, .voiceActivated:
            setWordProgress(Double(index))
        }
        persistDraft()
    }

    func jumpToEnd() {
        let lastIndex = max(currentWords.count - 1, 0)
        jumpToWord(index: lastIndex)
    }

    func goToNextPage() {
        guard let next = document.nextReadablePageIndex() else { return }
        transitionToPage(next, markCurrentPageRead: true)
        documentStatusMessage = "Moved to page \(next + 1)."
    }

    func goToPreviousPage() {
        guard let previous = document.previousReadablePageIndex() else { return }
        transitionToPage(previous)
        documentStatusMessage = "Returned to page \(previous + 1)."
    }

    func newDocument() {
        stopReading()
        launchRecoveryMessage = nil
        document = ScriptDocument(title: "Untitled", pages: [""])
        pageTitle = document.title
        currentDocumentURL = nil
        lastSavedSnapshot = nil
        reachedEndOfScript = false
        documentStatusMessage = "Started a new script."
        clearRuntimeErrors()
        persistDraft()
    }

    func importDocument(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                documentStatusMessage = "Import failed: unable to read file as UTF-8 text."
                return
            }
            let pages = text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let nonEmptyPages = pages.isEmpty ? [""] : pages
            stopReading()
            document = ScriptDocument(title: url.deletingPathExtension().lastPathComponent, pages: nonEmptyPages)
            pageTitle = document.title
            currentDocumentURL = nil
            lastSavedSnapshot = nil
            reachedEndOfScript = false
            documentStatusMessage = "Imported \(url.lastPathComponent) — \(document.pages.count) pages."
            triggerHaptic(style: .success)
            clearRuntimeErrors()
            persistDraft()
        } catch {
            documentStatusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func loadSampleScript(_ sample: IOSTeleprompterSample) {
        stopReading()
        launchRecoveryMessage = nil
        document = sample.document
        pageTitle = sample.document.title
        currentDocumentURL = nil
        lastSavedSnapshot = nil
        reachedEndOfScript = false
        documentStatusMessage = "Loaded the \(sample.title) sample."
        clearRuntimeErrors()
        persistDraft()
    }

    func saveDocument() {
        do {
            launchRecoveryMessage = nil
            document.title = normalizedTitle
            document.lastReadPageIndex = document.currentPageIndex
            document.lastReadWordIndex = currentWordIndex
            let savedURL = try documentLibrary.save(
                document: document,
                preferredTitle: normalizedTitle,
                currentURL: currentDocumentURL
            )
            currentDocumentURL = savedURL
            pageTitle = savedURL.deletingPathExtension().lastPathComponent
            document.title = pageTitle
            lastSavedSnapshot = normalizedCurrentSnapshot
            documentStatusMessage = "Saved to \(pageTitle).textream"
            triggerHaptic(style: .success)
            persistDraft()
        } catch {
            documentStatusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func loadDocument(_ item: SavedScriptDocument) {
        do {
            stopReading()
            launchRecoveryMessage = nil
            let loaded = try documentLibrary.load(item)
            document = loaded
            if document.lastReadPageIndex >= 0 && document.lastReadPageIndex < document.pages.count {
                document.currentPageIndex = document.lastReadPageIndex
            }
            currentDocumentURL = item.url
            pageTitle = item.title
            document.title = item.title
            lastSavedSnapshot = normalizedCurrentSnapshot
            reachedEndOfScript = false
            documentStatusMessage = "Opened \(item.title).textream"
            triggerHaptic(style: .success)
            persistDraft()
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

    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            refreshDocuments()
            if isReaderPresented && session.isPaused {
                documentStatusMessage = "Reader is paused. Tap Resume to continue."
            }
        case .background:
            if isReaderPresented {
                pauseForBackgroundTransition()
            }
            persistDraft()
        case .inactive:
            persistDraft()
        @unknown default:
            persistDraft()
        }
    }

    func dismissPresentedError() {
        presentedErrorMessage = nil
    }

    func dismissLaunchRecoveryMessage() {
        launchRecoveryMessage = nil
    }

    func resetReaderSettings() {
        isRestoringPersistentState = true
        selectedMode = .classic
        readerFontSize = IOSReaderFontSizing.default
        readerLineSpacing = 1.2
        keepScreenAwakeWhileReading = true
        hapticEnabled = true
        mirrorModeEnabled = false
        readerFontFamily = .rounded
        highlightColorPreset = .amber
        scrollSpeedWordsPerSecond = 2.0
        speechLocale = .system
        phoneticTooltipEnabled = true
        nativeLanguage = "zh"
        phoneticSource = .localDictionary
        isRestoringPersistentState = false
        persistReaderSettings()
        documentStatusMessage = "Reader settings reset to defaults."
    }

    func copyAllTextToClipboard() {
        let fullText = document.pages.joined(separator: "\n\n")
        UIPasteboard.general.string = fullText
        documentStatusMessage = "Copied full script to clipboard."
        triggerHaptic(style: .success)
    }

    func exportDocument() {
        let fullText = document.pages.joined(separator: "\n\n")
        guard !fullText.isEmpty else {
            documentStatusMessage = "Nothing to export."
            return
        }
        let safeName = currentDocumentDisplayName.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(safeName).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try fullText.write(to: tempURL, atomically: true, encoding: String.Encoding.utf8)
            exportDocumentURL = tempURL
            isExportSheetPresented = true
        } catch {
            documentStatusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func clearExportURL() {
        exportDocumentURL = nil
        isExportSheetPresented = false
    }

    func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            documentStatusMessage = "Clipboard is empty."
            return
        }
        let current = document.currentPageText
        let separator = current.isEmpty ? "" : "\n"
        let newText = current + separator + pasted
        let maxPageLength = 50000
        let trimmed = newText.count > maxPageLength ? String(newText.prefix(maxPageLength)) : newText
        document.setCurrentPageText(trimmed)
        documentStatusMessage = "Pasted from clipboard."
        triggerHaptic(style: .success)
        persistDraft()
    }

    func moveCurrentPageUp() {
        guard document.currentPageIndex > 0 else { return }
        document.moveCurrentPageUp()
        documentStatusMessage = "Moved page up."
        persistDraft()
    }

    func moveCurrentPageDown() {
        guard document.currentPageIndex + 1 < document.pages.count else { return }
        document.moveCurrentPageDown()
        documentStatusMessage = "Moved page down."
        persistDraft()
    }

    func duplicateCurrentPage() {
        let sourcePage = document.currentPageIndex + 1
        document.duplicateCurrentPage()
        documentStatusMessage = "Duplicated page \(sourcePage)."
        triggerHaptic(style: .success)
        persistDraft()
    }

    private var normalizedTitle: String {
        let trimmed = pageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func currentWordTrackingAnchor() -> Int {
        min(max(currentWordIndex, 0), max(currentWords.count - 1, 0))
    }

    private var currentPageLanguageSignal: (latinLetters: Int, cjkScalars: Int) {
        let text = document.currentPageText
        var latinLetters = 0
        var cjkScalars = 0
        for scalar in text.unicodeScalars {
            if scalar.properties.isIdeographic || scalar.value >= 0x3040 && scalar.value <= 0x30FF || scalar.value >= 0xAC00 && scalar.value <= 0xD7AF {
                cjkScalars += 1
            } else if (65...90).contains(scalar.value) || (97...122).contains(scalar.value) {
                latinLetters += 1
            }
        }
        return (latinLetters, cjkScalars)
    }

    private var shouldPreferEnglishWordTrackingLocale: Bool {
        let signal = currentPageLanguageSignal
        return signal.latinLetters >= max(6, signal.cjkScalars * 2)
    }

    private var resolvedWordTrackingLocaleIdentifier: String {
        if shouldPreferEnglishWordTrackingLocale,
           speechLocale != .englishUS,
           speechLocale != .englishUK {
            return IOSSpeechLocaleOption.englishUS.rawValue
        }

        if speechLocale != .system {
            return speechLocale.localeIdentifier
        }

        return Locale.autoupdatingCurrent.identifier
    }

    private var resolvedWordTrackingLocaleLabel: String {
        if shouldPreferEnglishWordTrackingLocale,
           speechLocale != .englishUS,
           speechLocale != .englishUK {
            return "English (auto)"
        }
        return speechLocale.label
    }

    private func startWordTrackingRecognizer(preservingCharCount: Int? = nil) {
        wordTracker.start(
            with: document.currentPageText,
            localeIdentifier: resolvedWordTrackingLocaleIdentifier,
            preservingCharCount: preservingCharCount,
            contextualHints: speechHintsForCurrentPage(),
            anchorWordIndex: currentWordTrackingAnchor()
        )
    }

    private func syncWordTrackingSessionFromRecognizer() {
        session.updateSpeech(
            charCount: wordTracker.recognizedCharCount,
            lastSpokenText: wordTracker.lastSpokenText,
            audioLevels: wordTracker.audioLevels,
            isListening: wordTracker.isListening
        )
    }

    private func speechHintsForCurrentPage() -> [String] {
        var candidates: [String] = []
        candidates.append(contentsOf: speechHintTokens(in: document.currentPageText, maxCount: 64))
        if let nextPageIndex = document.nextReadablePageIndex(skippingEmptyPages: false), document.pages.indices.contains(nextPageIndex) {
            candidates.append(contentsOf: speechHintTokens(in: document.pages[nextPageIndex], maxCount: 24))
        }
        candidates.append(contentsOf: speechHintTokens(in: normalizedTitle, maxCount: 8))
        candidates.append(contentsOf: document.tags)
        return orderedUniqueSpeechHints(candidates, limit: 80)
    }

    private func speechHintTokens(in text: String, maxCount: Int) -> [String] {
        let rawFragments = text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" })
            .map(String.init)
        let candidates = TextSegmentation.splitIntoWords(text) + rawFragments
        var results: [String] = []
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = trimmed.filter { $0.isLetter || $0.isNumber }
            guard normalized.count >= 2 || trimmed.contains(where: { $0.isNumber }) else { continue }
            results.append(trimmed)
            if results.count >= maxCount {
                break
            }
        }
        return results
    }

    private func orderedUniqueSpeechHints(_ candidates: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            ordered.append(trimmed)
            if ordered.count >= limit {
                break
            }
        }
        return ordered
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
            startWordTrackingRecognizer(preservingCharCount: session.recognizedCharCount)
            syncWordTrackingSessionFromRecognizer()
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
        hasAutoAdvancedCurrentPage = false
        if isReaderPresented {
            session.start(mode: newMode)
            restoreSessionForCurrentPage(restartEngines: true)
        }
        persistDraftIfNeeded()
    }

    private func restoreSessionForCurrentPage(restartEngines: Bool) {
        hasAutoAdvancedCurrentPage = false
        session.resetProgressForNewPage()
        session.start(mode: selectedMode)
        if restartEngines {
            syncAudioMonitoringForCurrentMode()
        }
    }

    private func pauseForBackgroundTransition() {
        session.pause()
        pauseActiveInputsForCurrentMode()
        documentStatusMessage = "Paused when Textream moved to the background."
    }

    private func consumeSubsystemErrors() {
        if let error = runtimeErrorMessage {
            presentError(error)
        }
    }

    private func clearRuntimeErrors() {
        audioMonitor.errorMessage = nil
        wordTracker.errorMessage = nil
        documentLibrary.errorMessage = nil
    }

    private func presentError(_ message: String) {
        presentedErrorMessage = message
        documentStatusMessage = message
    }

    private func loadPersistedState() {
        isRestoringPersistentState = true
        let settings = decode(IOSPersistedReaderSettings.self, forKey: readerSettingsKey) ?? IOSPersistedReaderSettings()
        selectedMode = settings.selectedMode
        readerFontSize = clampedReaderFontSize(settings.fontSize)
        readerLineSpacing = settings.lineSpacing
        keepScreenAwakeWhileReading = settings.keepScreenAwake
        hapticEnabled = settings.hapticEnabled
        mirrorModeEnabled = settings.mirrorModeEnabled
        forceDarkMode = settings.forceDarkMode
        readerFontFamily = settings.fontFamily
        highlightColorPreset = settings.highlightColor
        scrollSpeedWordsPerSecond = settings.scrollSpeedWordsPerSecond
        speechLocale = settings.speechLocale
        phoneticTooltipEnabled = settings.phoneticTooltipEnabled
        nativeLanguage = settings.nativeLanguage
        phoneticSource = settings.phoneticSource

        if let draft = decode(IOSDraftState.self, forKey: draftStateKey) {
            document = draft.document
            pageTitle = draft.pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draft.document.title : draft.pageTitle
            currentDocumentURL = draft.currentDocumentURL
            if draft.document.hasAnyContent || draft.currentDocumentURL != nil {
                launchRecoveryMessage = draft.currentDocumentURL == nil
                    ? String(localized: "Restored your last local draft.")
                    : String(localized: "Restored your last open script and local edits.")
            } else {
                launchRecoveryMessage = nil
            }
        } else {
            document = ScriptDocument(title: "Untitled", pages: [""])
            pageTitle = "Untitled"
            currentDocumentURL = nil
            launchRecoveryMessage = nil
        }
        document.title = normalizedTitle
        if let currentDocumentURL, let savedDocument = try? ScriptDocumentStore.load(from: currentDocumentURL) {
            lastSavedSnapshot = IOSDraftState(document: savedDocument, pageTitle: currentDocumentURL.deletingPathExtension().lastPathComponent, currentDocumentURL: currentDocumentURL)
        } else {
            lastSavedSnapshot = nil
        }
        isRestoringPersistentState = false
    }

    private func persistReaderSettingsIfNeeded() {
        guard !isRestoringPersistentState else { return }
        persistReaderSettings()
    }

    private func persistReaderSettings() {
        let settings = IOSPersistedReaderSettings(
            selectedMode: selectedMode,
            fontSize: readerFontSize,
            fontFamily: readerFontFamily,
            highlightColor: highlightColorPreset,
            scrollSpeedWordsPerSecond: scrollSpeedWordsPerSecond,
            speechLocale: speechLocale,
            lineSpacing: readerLineSpacing,
            keepScreenAwake: keepScreenAwakeWhileReading,
            hapticEnabled: hapticEnabled,
            mirrorModeEnabled: mirrorModeEnabled,
            forceDarkMode: forceDarkMode,
            phoneticTooltipEnabled: phoneticTooltipEnabled,
            nativeLanguage: nativeLanguage,
            phoneticSource: phoneticSource
        )
        encode(settings, forKey: readerSettingsKey)
    }

    private func persistDraftIfNeeded() {
        guard !isRestoringPersistentState else { return }
        persistDraft()
    }

    func persistDraft() {
        encode(normalizedCurrentSnapshot, forKey: draftStateKey)
        lastAutoSavedAt = Date()
    }

    private func clampedReaderFontSize(_ value: Double) -> Double {
        min(IOSReaderFontSizing.maximum, max(IOSReaderFontSizing.minimum, value))
    }


    func setBookmark() {
        document.bookmarkPageIndex = document.currentPageIndex
        document.bookmarkWordIndex = currentWordIndex
        documentStatusMessage = "Bookmark set at page \(document.currentPageIndex + 1)."
        triggerHaptic(style: .success)
        persistDraft()
    }

    func jumpToBookmark() {
        guard document.bookmarkPageIndex >= 0, document.bookmarkPageIndex < document.pages.count else {
            documentStatusMessage = "No bookmark set yet."
            return
        }
        let targetPage = document.bookmarkPageIndex
        let targetWord = document.bookmarkWordIndex
        if targetPage != document.currentPageIndex {
            _ = document.jump(to: targetPage)
            restoreSessionForCurrentPage(restartEngines: isReaderPresented)
        }
        if targetWord >= 0 {
            jumpToWord(index: min(targetWord, max(currentWords.count - 1, 0)))
        }
        documentStatusMessage = "Jumped to bookmark (page \(targetPage + 1))."
        triggerHaptic(style: .success)
        persistDraft()
    }

    func hasBookmark() -> Bool {
        document.bookmarkPageIndex >= 0 && document.bookmarkPageIndex < document.pages.count
    }

    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !document.tags.contains(trimmed) else { return }
        document.tags.append(trimmed)
        persistDraft()
    }

    func removeTag(_ tag: String) {
        document.tags.removeAll { $0 == tag }
        persistDraft()
    }

    func speakWord(_ word: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: speechLocale.localeIdentifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }

    private func encode<Value: Encodable>(_ value: Value, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            documentStatusMessage = "Failed to persist local draft state."
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func hasSameSaveContent(as snapshot: IOSDraftState) -> Bool {
        snapshot.pageTitle == normalizedTitle && snapshot.document.pages == document.pages
    }

    private var normalizedCurrentSnapshot: IOSDraftState {
        IOSDraftState(
            document: document,
            pageTitle: normalizedTitle,
            currentDocumentURL: currentDocumentURL
        )
    }

    private func moveToReadableStartPageIfNeeded() {
        guard document.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let firstReadablePage = document.pages.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return
        }
        _ = document.jump(to: firstReadablePage)
    }

    private func pauseActiveInputsForCurrentMode() {
        switch session.mode {
        case .classic:
            session.updateAudio(audioLevels: [], isListening: false)
        case .voiceActivated:
            audioMonitor.stop()
            session.updateAudio(audioLevels: [], isListening: false)
        case .wordTracking:
            wordTracker.stop()
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: [],
                isListening: false
            )
        }
    }

    private func resumeActiveInputsForCurrentMode() {
        guard isReaderPresented else { return }
        switch session.mode {
        case .classic:
            session.updateAudio(audioLevels: [], isListening: false)
        case .voiceActivated:
            audioMonitor.start()
            session.updateAudio(audioLevels: audioMonitor.audioLevels, isListening: audioMonitor.isRunning)
        case .wordTracking:
            startWordTrackingRecognizer(preservingCharCount: session.recognizedCharCount)
            syncWordTrackingSessionFromRecognizer()
        }
    }

    private func triggerHaptic(style: HapticStyle) {
        guard hapticEnabled else { return }
        switch style {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .impact:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    private enum HapticStyle {
        case success
        case impact
    }

    private func transitionToPage(_ index: Int, markCurrentPageRead: Bool = false) {
        if markCurrentPageRead {
            document.markCurrentPageRead()
        }
        _ = document.jump(to: index)
        hasAutoAdvancedCurrentPage = false
        session.resetProgressForNewPage()
        session.start(mode: selectedMode)
        syncAudioMonitoringForCurrentMode()
        persistDraft()
    }

    private func handleAutomaticPageCompletionIfNeeded() {
        guard isReaderPresented else { return }

        let reachedEnd: Bool
        switch session.mode {
        case .classic, .voiceActivated:
            guard !currentWords.isEmpty else {
                hasAutoAdvancedCurrentPage = false
                return
            }
            reachedEnd = session.wordProgress >= Double(max(currentWords.count - 1, 0))
        case .wordTracking:
            guard !currentCollapsedText.isEmpty else {
                hasAutoAdvancedCurrentPage = false
                return
            }
            reachedEnd = session.recognizedCharCount >= max(currentCollapsedText.count - 1, 0)
        }

        guard reachedEnd else {
            hasAutoAdvancedCurrentPage = false
            return
        }

        guard !hasAutoAdvancedCurrentPage else { return }
        hasAutoAdvancedCurrentPage = true

        if let next = document.nextReadablePageIndex() {
            transitionToPage(next, markCurrentPageRead: true)
            documentStatusMessage = "Auto-advanced to page \(next + 1)."
            return
        }

        document.markCurrentPageRead()
        session.pause()
        audioMonitor.stop()
        wordTracker.stop()
        reachedEndOfScript = true
        switch session.mode {
        case .classic:
            session.updateAudio(audioLevels: [], isListening: false)
        case .voiceActivated:
            session.updateAudio(audioLevels: [], isListening: false)
        case .wordTracking:
            session.updateSpeech(
                charCount: wordTracker.recognizedCharCount,
                lastSpokenText: wordTracker.lastSpokenText,
                audioLevels: [],
                isListening: false
            )
        }
        documentStatusMessage = "Reached the end of the script."
        persistDraft()
    }
}
