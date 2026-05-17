import XCTest

final class SpeechProgressMatcherTests: XCTestCase {
    func testConsumeSegmentsAdvancesOnExactMatch() {
        var matcher = SpeechProgressMatcher()
        matcher.start(with: "hello world this is a test")

        let decision = matcher.consumeSegments(["hello", "world"])

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("forward"))
        XCTAssertGreaterThan(decision.charCount, 0)
    }

    func testConsumeSegmentsUsesFuzzyWordMatching() {
        var matcher = SpeechProgressMatcher()
        matcher.start(with: "teleprompter rehearsal mode")

        _ = matcher.consumeSegments(["telepromter rehearsal"])
        let decision = matcher.consumeSegments(["telepromter rehearsal"])

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertGreaterThan(decision.charCount, 0)
    }

    func testPhraseAnchorFindsMatchInsideSpokenPreamble() {
        var matcher = SpeechProgressMatcher()
        matcher.start(with: "alpha beta gamma delta epsilon zeta eta theta")
        matcher.reanchor(nearWordIndex: 2)

        _ = matcher.consumeDecision(spoken: "please gamma delta epsilon now")
        let decision = matcher.consumeDecision(spoken: "please gamma delta epsilon now")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("phrase-anchor"))
        XCTAssertGreaterThan(decision.charCount, charOffset(forWordIndex: 3, in: "alpha beta gamma delta epsilon zeta eta theta"))
    }

    func testSmallRollbackCanReanchor() {
        let source = "one two three four five six seven eight"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)
        matcher.jumpTo(charOffset: charOffset(forWordIndex: 4, in: source))
        matcher.reanchor(nearWordIndex: 4)

        _ = matcher.consumeDecision(spoken: "four five six")
        let decision = matcher.consumeDecision(spoken: "four five six")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.didReanchor)
        XCTAssertTrue(decision.reason.contains("reanchor"))
    }

    func testLargeRollbackIsHeldOrRejected() {
        let source = "one two three four five six seven eight nine ten"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)
        matcher.jumpTo(charOffset: charOffset(forWordIndex: 9, in: source))
        matcher.reanchor(nearWordIndex: 8)

        let decision = matcher.consumeDecision(spoken: "one two three")

        XCTAssertFalse(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("hold") || decision.reason.contains("reject"))
    }

    func testAnnotationTokensAreSkippedDuringMatching() {
        let source = "hello [pause] world again"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)

        _ = matcher.consumeDecision(spoken: "hello world")
        let decision = matcher.consumeDecision(spoken: "hello world")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertGreaterThan(decision.charCount, charOffset(forWordIndex: 1, in: source))
    }

    func testCJKTokensAdvanceAsIndividualWords() {
        var matcher = SpeechProgressMatcher()
        matcher.start(with: "你好世界")

        _ = matcher.consumeSegments(["你", "好", "世"])
        let decision = matcher.consumeSegments(["你", "好", "世"])

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertGreaterThan(decision.charCount, 0)
        XCTAssertTrue(decision.reason.contains("forward"))
    }

    func testRepeatedPhraseAnchorsNearCurrentPosition() {
        let source = "alpha beta alpha beta gamma"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)
        matcher.jumpTo(charOffset: charOffset(forWordIndex: 2, in: source))
        matcher.reanchor(nearWordIndex: 2)

        _ = matcher.consumeDecision(spoken: "alpha beta gamma")
        let decision = matcher.consumeDecision(spoken: "alpha beta gamma")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("phrase-anchor"))
        XCTAssertGreaterThanOrEqual(decision.charCount, charOffset(forWordIndex: 4, in: source))
    }

    func testPunctuationAndNewlinesNormalizeForMatching() {
        let source = "hello,\nworld! next line"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)

        _ = matcher.consumeDecision(spoken: "hello world next")
        let decision = matcher.consumeDecision(spoken: "hello world next")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertGreaterThan(decision.charCount, charOffset(forWordIndex: 1, in: "hello, world! next line"))
    }

    func testMixedLanguageChineseEnglishPhraseAdvances() {
        let source = "今天 我们 聊 GPT4 Turbo 模型 发布 计划"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)

        let mixedSegments = ["今", "天", "我", "们", "聊", "GPT4", "Turbo", "模", "型"]
        _ = matcher.consumeSegments(mixedSegments)
        let decision = matcher.consumeSegments(mixedSegments)

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("phrase-anchor") || decision.reason.contains("forward"))
        XCTAssertGreaterThan(decision.charCount, 0)
    }

    func testMixedLanguagePhraseAnchorHandlesEnglishProductName() {
        let source = "今天 我们 讨论 Apple Vision Pro 演示 流程"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)
        matcher.reanchor(nearWordIndex: 2)

        let mixedSegments = ["Apple", "Vision", "Pro", "演", "示"]
        _ = matcher.consumeSegments(mixedSegments)
        let decision = matcher.consumeSegments(mixedSegments)

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertTrue(decision.reason.contains("phrase-anchor"))
        XCTAssertGreaterThanOrEqual(decision.charCount, charOffset(forWordIndex: 4, in: source))
    }

    func testVersionAndBuildNumbersNormalizeAcrossPunctuation() {
        let source = "版本 2.5 build 1024 已 发布"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)

        _ = matcher.consumeDecision(spoken: "版本 25 build 1024 已 发布")
        let decision = matcher.consumeDecision(spoken: "版本 25 build 1024 已 发布")

        XCTAssertTrue(decision.shouldCommit)
        XCTAssertGreaterThanOrEqual(decision.charCount, charOffset(forWordIndex: 4, in: source))
    }

    func testAdvanceToFutureMatchingTokenSkipsShortBlockedWordWhenFutureWordIsPresent() {
        let source = "This is a short script"
        var matcher = SpeechProgressMatcher()
        matcher.start(with: source)
        matcher.jumpTo(charOffset: charOffset(forWordIndex: 2, in: source))
        matcher.reanchor(nearWordIndex: 2)

        let forced = matcher.advanceToFutureMatchingToken(using: "This is a short script")

        XCTAssertGreaterThanOrEqual(forced, charOffset(forWordIndex: 3, in: source))
    }

    private func charOffset(forWordIndex wordIndex: Int, in text: String) -> Int {
        let words = text.split(separator: " ").map(String.init)
        let clamped = min(max(wordIndex, 0), words.count)
        var offset = 0
        for index in 0..<clamped {
            offset += words[index].count + 1
        }
        return offset
    }
}
