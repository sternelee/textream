import Foundation

/// Shared fuzzy matching engine used to advance a teleprompter through spoken text.
/// Mirrors the current macOS matching behavior closely enough for the iOS MVP.
struct SpeechProgressMatcher {
    private(set) var sourceText: String = ""
    private(set) var recognizedCharCount: Int = 0
    private var matchStartOffset: Int = 0
    private var recentMatchPositions: [Int] = []

    mutating func start(with rawText: String) {
        let words = TextSegmentation.splitIntoWords(rawText)
        sourceText = words.joined(separator: " ")
        recognizedCharCount = 0
        matchStartOffset = 0
        recentMatchPositions = []
    }

    mutating func updateText(_ rawText: String, preservingCharCount: Int) {
        let words = TextSegmentation.splitIntoWords(rawText)
        sourceText = words.joined(separator: " ")
        recognizedCharCount = min(max(0, preservingCharCount), sourceText.count)
        matchStartOffset = recognizedCharCount
        recentMatchPositions = []
    }

    mutating func jumpTo(charOffset: Int) {
        let clamped = min(max(0, charOffset), sourceText.count)
        recognizedCharCount = clamped
        matchStartOffset = clamped
        recentMatchPositions = []
    }

    mutating func consume(spoken: String) -> Int {
        guard !sourceText.isEmpty else { return 0 }

        let charResult = charLevelMatch(spoken: spoken)
        let wordResult = wordLevelMatch(spoken: spoken)

        let tolerance = 20
        let best: Int
        if abs(charResult - wordResult) <= tolerance {
            best = (charResult + wordResult) / 2
        } else {
            best = min(charResult, wordResult)
        }

        let newCount = matchStartOffset + best
        guard newCount > recognizedCharCount else { return recognizedCharCount }

        let candidate = min(newCount, sourceText.count)
        recentMatchPositions.append(candidate)
        if recentMatchPositions.count > 3 {
            recentMatchPositions.removeFirst()
        }

        let agreementThreshold = 10
        var confirmed = false
        if recentMatchPositions.count >= 2 {
            var agreeCount = 0
            for position in recentMatchPositions where abs(position - candidate) <= agreementThreshold {
                agreeCount += 1
            }
            confirmed = agreeCount >= 2
        }

        let smallStep = candidate - recognizedCharCount <= 15
        if confirmed || smallStep {
            recognizedCharCount = candidate
        }

        return recognizedCharCount
    }

    mutating func prepareForRestart() {
        matchStartOffset = recognizedCharCount
        recentMatchPositions = []
    }

    private func charLevelMatch(spoken: String) -> Int {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let src = Array(remainingSource.lowercased())
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

    private func wordLevelMatch(spoken: String) -> Int {
        let remainingSource = String(sourceText.dropFirst(matchStartOffset))
        let sourceWords = remainingSource.split(separator: " ").map(String.init)
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

            let srcWord = sourceWords[si].lowercased().filter { $0.isLetter || $0.isNumber }
            let spkWord = spokenWords[ri].filter { $0.isLetter || $0.isNumber }

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
                        let nextSpk = spokenWords[ri + skip].filter { $0.isLetter || $0.isNumber }
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
                        let nextSrc = sourceWords[si + skip].lowercased().filter { $0.isLetter || $0.isNumber }
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

    private static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
    }
}
