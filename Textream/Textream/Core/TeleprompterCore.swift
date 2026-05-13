import Foundation

/// Platform-neutral reading modes shared by future iOS and macOS shells.
enum TeleprompterMode: String, CaseIterable, Codable, Identifiable {
    case wordTracking
    case classic
    case voiceActivated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wordTracking: return "Word Tracking"
        case .classic: return "Classic"
        case .voiceActivated: return "Voice-Activated"
        }
    }
}

/// Platform-neutral script container.
/// Keeps pagination, current position, and read-page bookkeeping separate from UI.
struct ScriptDocument: Codable, Equatable {
    var title: String
    var pages: [String]
    var currentPageIndex: Int
    var readPages: Set<Int>

    init(
        title: String = "Untitled",
        pages: [String] = [""],
        currentPageIndex: Int = 0,
        readPages: Set<Int> = []
    ) {
        let normalizedPages = pages.isEmpty ? [""] : pages
        self.title = title
        self.pages = normalizedPages
        self.currentPageIndex = min(max(0, currentPageIndex), normalizedPages.count - 1)
        self.readPages = readPages.filter { $0 >= 0 && $0 < normalizedPages.count }
    }

    var currentPageText: String {
        guard pages.indices.contains(currentPageIndex) else { return "" }
        return pages[currentPageIndex]
    }

    var hasAnyContent: Bool {
        pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var hasNextPage: Bool {
        nextReadablePageIndex() != nil
    }

    var hasPreviousPage: Bool {
        previousReadablePageIndex() != nil
    }

    mutating func setCurrentPageText(_ text: String) {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex] = text
    }

    @discardableResult
    mutating func addPage(after index: Int? = nil, text: String = "") -> Int {
        let insertIndex: Int
        if let index, pages.indices.contains(index) {
            insertIndex = index + 1
        } else {
            insertIndex = pages.count
        }

        pages.insert(text, at: insertIndex)

        readPages = Set(readPages.map { existing in
            existing >= insertIndex ? existing + 1 : existing
        })

        currentPageIndex = insertIndex
        return insertIndex
    }

    mutating func removePage(at index: Int) {
        guard pages.indices.contains(index), pages.count > 1 else { return }

        pages.remove(at: index)
        readPages.remove(index)
        readPages = Set(readPages.compactMap { existing in
            if existing > index { return existing - 1 }
            if existing < index { return existing }
            return nil
        })

        if currentPageIndex >= pages.count {
            currentPageIndex = pages.count - 1
        } else if currentPageIndex > index {
            currentPageIndex -= 1
        }
    }

    @discardableResult
    mutating func jump(to index: Int) -> Bool {
        guard pages.indices.contains(index) else { return false }
        currentPageIndex = index
        return true
    }

    mutating func markPageRead(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        readPages.insert(index)
    }

    mutating func markCurrentPageRead() {
        markPageRead(currentPageIndex)
    }

    func pagePreview(at index: Int, wordLimit: Int = 5, characterLimit: Int = 30) -> String {
        guard pages.indices.contains(index) else { return "" }
        let trimmed = pages[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Empty" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let preview = words.prefix(wordLimit).joined(separator: " ")
        if preview.count > characterLimit {
            return String(preview.prefix(characterLimit)) + "…"
        }
        return preview
    }

    func nextReadablePageIndex(skippingEmptyPages: Bool = true) -> Int? {
        guard !pages.isEmpty else { return nil }
        var index = currentPageIndex + 1
        while index < pages.count {
            if !skippingEmptyPages || !pages[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return index
            }
            index += 1
        }
        return nil
    }

    func previousReadablePageIndex(skippingEmptyPages: Bool = true) -> Int? {
        guard !pages.isEmpty, currentPageIndex > 0 else { return nil }
        var index = currentPageIndex - 1
        while index >= 0 {
            if !skippingEmptyPages || !pages[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return index
            }
            index -= 1
        }
        return nil
    }

    @discardableResult
    mutating func advanceToNextReadablePage(skippingEmptyPages: Bool = true) -> Int? {
        guard let nextIndex = nextReadablePageIndex(skippingEmptyPages: skippingEmptyPages) else {
            return nil
        }
        currentPageIndex = nextIndex
        return nextIndex
    }
}

/// Cross-platform reading session state.
/// Keeps timing/speech-driven progression independent from the presentation shell.
struct ReadingSessionState: Equatable {
    var mode: TeleprompterMode
    var isRunning: Bool
    var isPaused: Bool
    var wordProgress: Double
    var recognizedCharCount: Int
    var audioLevels: [Double]
    var isListening: Bool
    var lastSpokenText: String

    init(
        mode: TeleprompterMode = .wordTracking,
        isRunning: Bool = false,
        isPaused: Bool = false,
        wordProgress: Double = 0,
        recognizedCharCount: Int = 0,
        audioLevels: [Double] = [],
        isListening: Bool = false,
        lastSpokenText: String = ""
    ) {
        self.mode = mode
        self.isRunning = isRunning
        self.isPaused = isPaused
        self.wordProgress = max(0, wordProgress)
        self.recognizedCharCount = max(0, recognizedCharCount)
        self.audioLevels = audioLevels
        self.isListening = isListening
        self.lastSpokenText = lastSpokenText
    }

    mutating func start(mode: TeleprompterMode? = nil) {
        if let mode {
            self.mode = mode
        }
        isRunning = true
        isPaused = false
    }

    mutating func stop() {
        isRunning = false
        isPaused = false
        isListening = false
        lastSpokenText = ""
    }

    mutating func pause() {
        guard isRunning else { return }
        isPaused = true
    }

    mutating func resume() {
        guard isRunning else { return }
        isPaused = false
    }

    mutating func togglePause() {
        isPaused ? resume() : pause()
    }

    mutating func resetProgressForNewPage() {
        wordProgress = 0
        recognizedCharCount = 0
        lastSpokenText = ""
    }

    mutating func applyClassicProgress(deltaWords: Double, totalWordCount: Int) {
        guard isRunning, !isPaused, mode != .wordTracking else { return }
        let upperBound = Double(max(totalWordCount, 0))
        wordProgress = min(upperBound, max(0, wordProgress + deltaWords))
    }

    mutating func updateSpeech(charCount: Int, lastSpokenText: String, audioLevels: [Double], isListening: Bool) {
        recognizedCharCount = max(0, charCount)
        self.lastSpokenText = lastSpokenText
        self.audioLevels = audioLevels
        self.isListening = isListening
    }

    mutating func updateAudio(audioLevels: [Double], isListening: Bool) {
        self.audioLevels = audioLevels
        self.isListening = isListening
    }
}
