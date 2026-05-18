import Foundation

/// Platform-neutral reading modes shared by future iOS and macOS shells.
enum TeleprompterMode: String, CaseIterable, Codable, Identifiable {
    case wordTracking
    case classic
    case voiceActivated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wordTracking: return String(localized: "Word Tracking")
        case .classic: return String(localized: "Classic")
        case .voiceActivated: return String(localized: "Voice-Activated")
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
    var lastReadPageIndex: Int
    var lastReadWordIndex: Int
    var tags: [String]
    var bookmarkPageIndex: Int
    var bookmarkWordIndex: Int

    init(
        title: String = "Untitled",
        pages: [String] = [""],
        currentPageIndex: Int = 0,
        readPages: Set<Int> = [],
        lastReadPageIndex: Int = -1,
        lastReadWordIndex: Int = -1,
        tags: [String] = [],
        bookmarkPageIndex: Int = -1,
        bookmarkWordIndex: Int = -1
    ) {
        let normalizedPages = pages.isEmpty ? [""] : pages
        self.title = title
        self.pages = normalizedPages
        self.currentPageIndex = min(max(0, currentPageIndex), normalizedPages.count - 1)
        self.readPages = readPages.filter { $0 >= 0 && $0 < normalizedPages.count }
        self.lastReadPageIndex = lastReadPageIndex
        self.lastReadWordIndex = lastReadWordIndex
        self.tags = tags
        self.bookmarkPageIndex = bookmarkPageIndex
        self.bookmarkWordIndex = bookmarkWordIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        pages = try container.decode([String].self, forKey: .pages)
        currentPageIndex = try container.decode(Int.self, forKey: .currentPageIndex)
        readPages = try container.decode(Set<Int>.self, forKey: .readPages)
        lastReadPageIndex = try container.decodeIfPresent(Int.self, forKey: .lastReadPageIndex) ?? -1
        lastReadWordIndex = try container.decodeIfPresent(Int.self, forKey: .lastReadWordIndex) ?? -1
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        bookmarkPageIndex = try container.decodeIfPresent(Int.self, forKey: .bookmarkPageIndex) ?? -1
        bookmarkWordIndex = try container.decodeIfPresent(Int.self, forKey: .bookmarkWordIndex) ?? -1
        if pages.isEmpty { pages = [""] }
        currentPageIndex = min(max(0, currentPageIndex), pages.count - 1)
        readPages = readPages.filter { $0 >= 0 && $0 < pages.count }
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

    mutating func movePage(from sourceIndex: Int, to destinationIndex: Int) {
        guard pages.indices.contains(sourceIndex),
              pages.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }
        pages.swapAt(sourceIndex, destinationIndex)

        let wasSourceRead = readPages.contains(sourceIndex)
        let wasDestRead = readPages.contains(destinationIndex)
        readPages.remove(sourceIndex)
        readPages.remove(destinationIndex)
        if wasSourceRead { readPages.insert(destinationIndex) }
        if wasDestRead { readPages.insert(sourceIndex) }

        if currentPageIndex == sourceIndex {
            currentPageIndex = destinationIndex
        } else if currentPageIndex == destinationIndex {
            currentPageIndex = sourceIndex
        }
    }

    mutating func moveCurrentPageUp() {
        guard currentPageIndex > 0 else { return }
        movePage(from: currentPageIndex, to: currentPageIndex - 1)
    }

    mutating func moveCurrentPageDown() {
        guard currentPageIndex + 1 < pages.count else { return }
        movePage(from: currentPageIndex, to: currentPageIndex + 1)
    }

    mutating func markPageRead(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        readPages.insert(index)
    }

    mutating func markCurrentPageRead() {
        markPageRead(currentPageIndex)
    }

    @discardableResult
    mutating func duplicateCurrentPage() -> Int {
        guard pages.indices.contains(currentPageIndex) else { return currentPageIndex }
        let text = pages[currentPageIndex]
        let insertIndex = currentPageIndex + 1
        pages.insert(text, at: insertIndex)
        readPages = Set(readPages.map { existing in
            existing >= insertIndex ? existing + 1 : existing
        })
        currentPageIndex = insertIndex
        return insertIndex
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
