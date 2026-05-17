import Foundation

/// Shared fuzzy matching engine used to advance a teleprompter through spoken text.
/// Mirrors the current macOS matching behavior closely enough for the iOS MVP.
struct SpeechProgressMatcher {
    struct MatchDecision {
        let charCount: Int
        let tokenIndex: Int
        let shouldCommit: Bool
        let didReanchor: Bool
        let reason: String
    }

    private struct SourceToken {
        let raw: String
        let normalized: String
        let startChar: Int
        let endChar: Int
        let isAnnotation: Bool
    }

    private enum MatchingTuning {
        static let tolerance = 20
        static let agreementThreshold = 10
        static let smallForwardStepChars = 15
        static let rollbackCommitTokens = 5
        static let rollbackHoldTokens = 10
        static let windowBackTokens = 8
        static let windowForwardTokens = 28
        static let phraseAnchorMinWords = 3
        static let strongPhraseAnchorWords = 4
        static let phraseAnchorBlendDistance = 12
        static let phraseSpokenWindow = 6
    }

    private(set) var sourceText: String = ""
    private(set) var recognizedCharCount: Int = 0
    private var matchStartOffset: Int = 0
    private var recentMatchPositions: [Int] = []
    private var sourceTokens: [SourceToken] = []
    private var currentAnchorTokenIndex = 0

    mutating func start(with rawText: String) {
        setSourceText(Self.canonicalText(from: rawText), preservingCharCount: 0)
    }

    mutating func updateText(_ rawText: String, preservingCharCount: Int) {
        setSourceText(Self.canonicalText(from: rawText), preservingCharCount: preservingCharCount)
    }

    mutating func jumpTo(charOffset: Int) {
        let clamped = min(max(0, charOffset), sourceText.count)
        recognizedCharCount = clamped
        matchStartOffset = clamped
        currentAnchorTokenIndex = tokenIndex(forCharOffset: clamped)
        recentMatchPositions = []
    }

    mutating func reanchor(nearWordIndex index: Int) {
        guard !sourceTokens.isEmpty else {
            currentAnchorTokenIndex = 0
            matchStartOffset = recognizedCharCount
            recentMatchPositions = []
            return
        }
        currentAnchorTokenIndex = min(max(index, 0), max(sourceTokens.count - 1, 0))
        matchStartOffset = sourceTokens[currentAnchorTokenIndex].startChar
        recentMatchPositions = []
    }

    var currentTokenIndex: Int {
        tokenIndex(forCharOffset: recognizedCharCount)
    }

    var currentTokenIsShort: Bool {
        guard !sourceTokens.isEmpty else { return false }
        return sourceTokens[currentTokenIndex].normalized.count <= 2
    }

    mutating func consume(spoken: String) -> Int {
        consumeDecision(spoken: spoken).charCount
    }

    mutating func consumeSegments(_ texts: [String]) -> MatchDecision {
        let merged = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return consumeDecision(spoken: merged)
    }

    mutating func consumeDecision(spoken: String) -> MatchDecision {
        guard !sourceTokens.isEmpty else {
            return MatchDecision(
                charCount: 0,
                tokenIndex: 0,
                shouldCommit: false,
                didReanchor: false,
                reason: "empty-source"
            )
        }

        let normalizedSpoken = Self.normalize(spoken)
        guard !normalizedSpoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return MatchDecision(
                charCount: recognizedCharCount,
                tokenIndex: currentAnchorTokenIndex,
                shouldCommit: false,
                didReanchor: false,
                reason: "empty-spoken"
            )
        }

        let window = tokenWindow(around: currentAnchorTokenIndex)
        guard !window.tokens.isEmpty else {
            return MatchDecision(
                charCount: recognizedCharCount,
                tokenIndex: currentAnchorTokenIndex,
                shouldCommit: false,
                didReanchor: false,
                reason: "empty-window"
            )
        }

        let windowText = window.tokens.map(\.raw).joined(separator: " ")
        let charResult = charLevelMatch(spoken: spoken, source: windowText)
        let wordResult = wordLevelMatch(spoken: spoken, sourceWords: window.tokens.map(\.raw))
        let phraseAnchor = phraseAnchorMatch(spoken: normalizedSpoken, in: window.tokens, windowStartIndex: window.startIndex)

        var bestLocal: Int
        var usedPhraseAnchor = false
        if abs(charResult - wordResult) <= MatchingTuning.tolerance {
            bestLocal = (charResult + wordResult) / 2
        } else {
            bestLocal = min(charResult, wordResult)
        }

        if let phraseAnchor {
            if phraseAnchor.matchedWords >= MatchingTuning.strongPhraseAnchorWords {
                bestLocal = phraseAnchor.localCharOffset
                usedPhraseAnchor = true
            } else if abs(phraseAnchor.localCharOffset - bestLocal) <= MatchingTuning.phraseAnchorBlendDistance {
                bestLocal = (bestLocal + phraseAnchor.localCharOffset) / 2
                usedPhraseAnchor = true
            }
        }

        let candidate = min(max(window.baseCharOffset + bestLocal, 0), sourceText.count)
        let candidateTokenIndex = tokenIndex(forCharOffset: candidate)
        let currentTokenIndex = tokenIndex(forCharOffset: recognizedCharCount)
        let rollbackTokens = max(currentTokenIndex - candidateTokenIndex, 0)
        let forwardChars = max(candidate - recognizedCharCount, 0)
        let isReanchorCandidate = rollbackTokens > 0

        recentMatchPositions.append(candidate)
        if recentMatchPositions.count > 3 {
            recentMatchPositions.removeFirst()
        }

        let confirmed = isCandidateConfirmed(candidate)
        let shouldCommit: Bool
        let reasonCore: String

        if candidate >= recognizedCharCount {
            shouldCommit = confirmed || forwardChars <= MatchingTuning.smallForwardStepChars
            reasonCore = shouldCommit
                ? (confirmed ? "confirmed-forward" : "small-forward-step")
                : "hold-unconfirmed-forward"
        } else if rollbackTokens <= MatchingTuning.rollbackCommitTokens {
            shouldCommit = confirmed || rollbackTokens <= 2
            reasonCore = shouldCommit
                ? (confirmed ? "confirmed-reanchor" : "small-reanchor")
                : "hold-reanchor"
        } else if rollbackTokens <= MatchingTuning.rollbackHoldTokens {
            shouldCommit = false
            reasonCore = "hold-large-reanchor"
        } else {
            shouldCommit = false
            reasonCore = "reject-far-reanchor"
        }

        let reason = usedPhraseAnchor ? "\(reasonCore)-phrase-anchor" : reasonCore

        if shouldCommit {
            recognizedCharCount = candidate
            matchStartOffset = candidate
            currentAnchorTokenIndex = candidateTokenIndex
        }

        return MatchDecision(
            charCount: recognizedCharCount,
            tokenIndex: currentAnchorTokenIndex,
            shouldCommit: shouldCommit,
            didReanchor: shouldCommit && isReanchorCandidate,
            reason: reason
        )
    }

    mutating func prepareForRestart() {
        matchStartOffset = recognizedCharCount
        currentAnchorTokenIndex = tokenIndex(forCharOffset: recognizedCharCount)
        recentMatchPositions = []
    }

    mutating func nudgeForwardOneToken() -> Int {
        guard !sourceTokens.isEmpty else { return recognizedCharCount }
        let currentIndex = tokenIndex(forCharOffset: recognizedCharCount)
        let nextIndex = min(currentIndex + 1, sourceTokens.count - 1)
        guard nextIndex > currentIndex else { return recognizedCharCount }
        return moveToTokenStart(at: nextIndex)
    }

    mutating func advanceToFutureMatchingToken(using spoken: String) -> Int {
        guard !sourceTokens.isEmpty else { return recognizedCharCount }
        let spokenWords = spoken
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { Self.normalizeToken(String($0)) }
            .filter { !$0.isEmpty }
        guard !spokenWords.isEmpty else { return recognizedCharCount }

        let currentIndex = tokenIndex(forCharOffset: recognizedCharCount)
        let searchEnd = min(currentIndex + 3, sourceTokens.count - 1)
        if searchEnd > currentIndex {
            for candidateIndex in (currentIndex + 1)...searchEnd {
                let token = sourceTokens[candidateIndex]
                guard !token.isAnnotation, token.normalized.count >= 3 else { continue }
                if spokenWords.contains(where: { $0 == token.normalized || isFuzzyMatch(token.normalized, $0) }) {
                    return moveToTokenStart(at: candidateIndex)
                }
            }
        }

        return recognizedCharCount
    }

    private mutating func setSourceText(_ canonicalText: String, preservingCharCount: Int) {
        sourceText = canonicalText
        sourceTokens = Self.buildSourceTokens(from: canonicalText)
        recognizedCharCount = min(max(0, preservingCharCount), sourceText.count)
        matchStartOffset = recognizedCharCount
        currentAnchorTokenIndex = tokenIndex(forCharOffset: recognizedCharCount)
        recentMatchPositions = []
    }

    private mutating func moveToTokenStart(at index: Int) -> Int {
        let clamped = min(max(index, 0), max(sourceTokens.count - 1, 0))
        let nextOffset = sourceTokens[clamped].startChar
        recognizedCharCount = max(recognizedCharCount, nextOffset)
        matchStartOffset = recognizedCharCount
        currentAnchorTokenIndex = clamped
        recentMatchPositions = []
        return recognizedCharCount
    }

    private func tokenWindow(around anchorIndex: Int) -> (tokens: [SourceToken], startIndex: Int, endIndex: Int, baseCharOffset: Int) {
        guard !sourceTokens.isEmpty else {
            return ([], 0, 0, 0)
        }
        let safeAnchor = min(max(anchorIndex, 0), max(sourceTokens.count - 1, 0))
        let startIndex = max(0, safeAnchor - MatchingTuning.windowBackTokens)
        let endIndex = min(sourceTokens.count - 1, safeAnchor + MatchingTuning.windowForwardTokens)
        let windowTokens = Array(sourceTokens[startIndex...endIndex])
        let baseCharOffset = windowTokens.first?.startChar ?? 0
        return (windowTokens, startIndex, endIndex, baseCharOffset)
    }

    private func tokenIndex(forCharOffset charOffset: Int) -> Int {
        guard !sourceTokens.isEmpty else { return 0 }
        let clamped = min(max(0, charOffset), sourceText.count)
        for (index, token) in sourceTokens.enumerated() where clamped <= token.endChar {
            return index
        }
        return max(sourceTokens.count - 1, 0)
    }

    private func isCandidateConfirmed(_ candidate: Int) -> Bool {
        guard recentMatchPositions.count >= 2 else { return false }
        var agreeCount = 0
        for position in recentMatchPositions where abs(position - candidate) <= MatchingTuning.agreementThreshold {
            agreeCount += 1
        }
        return agreeCount >= 2
    }

    private func phraseAnchorMatch(spoken: String, in windowTokens: [SourceToken], windowStartIndex: Int) -> (localCharOffset: Int, matchedWords: Int)? {
        let spokenWords = spoken
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard spokenWords.count >= MatchingTuning.phraseAnchorMinWords else { return nil }

        let baseChar = windowTokens.first?.startChar ?? 0
        var bestMatch: (localCharOffset: Int, matchedWords: Int, distanceToAnchor: Int)?

        for spokenStart in spokenWords.indices {
            let spokenRemaining = spokenWords.count - spokenStart
            guard spokenRemaining >= MatchingTuning.phraseAnchorMinWords else { continue }
            for tokenStart in windowTokens.indices {
                var matchedWords = 0
                var tokenIndex = tokenStart
                var spokenIndex = spokenStart
                var lastMatchedTokenIndex: Int?

                while tokenIndex < windowTokens.count,
                      spokenIndex < spokenWords.count,
                      (spokenIndex - spokenStart) < MatchingTuning.phraseSpokenWindow {
                    let token = windowTokens[tokenIndex]
                    if token.isAnnotation {
                        tokenIndex += 1
                        continue
                    }

                    let spokenWord = spokenWords[spokenIndex]
                    if token.normalized == spokenWord || isFuzzyMatch(token.normalized, spokenWord) {
                        matchedWords += 1
                        lastMatchedTokenIndex = tokenIndex
                        tokenIndex += 1
                        spokenIndex += 1
                    } else {
                        break
                    }
                }

                guard matchedWords >= MatchingTuning.phraseAnchorMinWords,
                      let lastMatchedTokenIndex else { continue }
                let localCharOffset = windowTokens[lastMatchedTokenIndex].endChar - baseChar
                let anchorDistance = abs((windowStartIndex + tokenStart) - currentAnchorTokenIndex)
                if let best = bestMatch {
                    if matchedWords > best.matchedWords ||
                        (matchedWords == best.matchedWords && anchorDistance < best.distanceToAnchor) {
                        bestMatch = (localCharOffset, matchedWords, anchorDistance)
                    }
                } else {
                    bestMatch = (localCharOffset, matchedWords, anchorDistance)
                }
            }
        }

        guard let bestMatch else { return nil }
        return (bestMatch.localCharOffset, bestMatch.matchedWords)
    }

    private func charLevelMatch(spoken: String, source: String) -> Int {
        let src = Array(source.lowercased())
        let spk = Array(Self.normalize(spoken))

        var si = 0
        var ri = 0
        var lastGoodOrigIndex = 0

        while si < src.count && ri < spk.count {
            let sc = src[si]
            let rc = spk[ri]

            if !sc.isLetter && !sc.isNumber {
                si += 1
                continue
            }
            if !rc.isLetter && !rc.isNumber {
                ri += 1
                continue
            }

            if sc == rc {
                si += 1
                ri += 1
                lastGoodOrigIndex = si
            } else {
                var found = false

                let maxSkipR = min(3, spk.count - ri - 1)
                if maxSkipR >= 1 {
                    for skipR in 1...maxSkipR {
                        let nextRI = ri + skipR
                        if nextRI < spk.count && spk[nextRI] == sc {
                            ri = nextRI
                            found = true
                            break
                        }
                    }
                }
                if found { continue }

                let maxSkipS = min(3, src.count - si - 1)
                if maxSkipS >= 1 {
                    for skipS in 1...maxSkipS {
                        let nextSI = si + skipS
                        if nextSI < src.count && src[nextSI] == rc {
                            si = nextSI
                            found = true
                            break
                        }
                    }
                }
                if found { continue }

                ri += 1
            }
        }

        return lastGoodOrigIndex
    }

    private func wordLevelMatch(spoken: String, sourceWords: [String]) -> Int {
        let spokenWords = spoken.lowercased().split(separator: " ").map(String.init)

        var si = 0
        var ri = 0
        var matchedCharCount = 0

        while si < sourceWords.count && ri < spokenWords.count {
            if TextSegmentation.isAnnotationWord(sourceWords[si]) {
                matchedCharCount += sourceWords[si].count
                if si < sourceWords.count - 1 { matchedCharCount += 1 }
                si += 1
                continue
            }

            let srcWord = Self.normalizeToken(sourceWords[si])
            let spkWord = Self.normalizeToken(spokenWords[ri])

            if srcWord == spkWord || isFuzzyMatch(srcWord, spkWord) {
                matchedCharCount += sourceWords[si].count
                si += 1
                ri += 1
                if si < sourceWords.count { matchedCharCount += 1 }
            } else {
                var foundSpk = false
                let maxSpkSkip = min(3, spokenWords.count - ri - 1)
                if maxSpkSkip >= 1 {
                    for skip in 1...maxSpkSkip {
                        let nextSpk = Self.normalizeToken(spokenWords[ri + skip])
                        if srcWord == nextSpk || isFuzzyMatch(srcWord, nextSpk) {
                            ri += skip
                            foundSpk = true
                            break
                        }
                    }
                }
                if foundSpk { continue }

                var foundSrc = false
                let maxSrcSkip = min(3, sourceWords.count - si - 1)
                if maxSrcSkip >= 1 {
                    for skip in 1...maxSrcSkip {
                        let nextSrc = Self.normalizeToken(sourceWords[si + skip])
                        if nextSrc == spkWord || isFuzzyMatch(nextSrc, spkWord) {
                            for offset in 0..<skip {
                                matchedCharCount += sourceWords[si + offset].count + 1
                            }
                            si += skip
                            foundSrc = true
                            break
                        }
                    }
                }
                if foundSrc { continue }

                if srcWord.isEmpty {
                    matchedCharCount += sourceWords[si].count
                    if si < sourceWords.count - 1 { matchedCharCount += 1 }
                    si += 1
                    continue
                }

                ri += 1
            }
        }

        while si < sourceWords.count && TextSegmentation.isAnnotationWord(sourceWords[si]) {
            matchedCharCount += sourceWords[si].count
            if si < sourceWords.count - 1 { matchedCharCount += 1 }
            si += 1
        }

        return matchedCharCount
    }

    private func isFuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a.isEmpty || b.isEmpty { return false }
        if a == b { return true }
        let shorter = min(a.count, b.count)
        if shorter >= 3 && (a.hasPrefix(b) || b.hasPrefix(a)) { return true }
        let shared = zip(a, b).prefix(while: { $0 == $1 }).count
        if shorter >= 3 && shared >= max(3, shorter * 3 / 5) { return true }
        let dist = editDistance(a, b)
        if shorter <= 2 { return false }
        if shorter <= 4 { return dist <= 1 }
        if shorter <= 8 { return dist <= 2 }
        return dist <= max(a.count, b.count) / 3
    }

    private func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var previous = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i - 1] == b[j - 1] ? previous : min(previous, dp[j], dp[j - 1]) + 1
                previous = temp
            }
        }
        return dp[b.count]
    }

    private static func canonicalText(from rawText: String) -> String {
        TextSegmentation.splitIntoWords(rawText).joined(separator: " ")
    }

    private static func buildSourceTokens(from text: String) -> [SourceToken] {
        let words = text.split(separator: " ").map(String.init)
        var tokens: [SourceToken] = []
        var startChar = 0
        for word in words {
            let endChar = startChar + word.count
            tokens.append(
                SourceToken(
                    raw: word,
                    normalized: normalizeToken(word),
                    startChar: startChar,
                    endChar: endChar,
                    isAnnotation: TextSegmentation.isAnnotationWord(word)
                )
            )
            startChar = endChar + 1
        }
        return tokens
    }

    private static func normalizeToken(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }
}
