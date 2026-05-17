import AVFoundation
import Foundation
import Speech

@Observable
final class IOSWordTrackingRecognizer {
    var recognizedCharCount: Int = 0
    var isListening = false
    var audioLevels: [Double] = Array(repeating: 0, count: 24)
    var lastSpokenText: String = ""
    var errorMessage: String?
    var microphonePermissionDenied = false
    var speechPermissionDenied = false
    var currentLocaleIdentifier: String = Locale.current.identifier
    var trackingDebugMessage: String?
    var trackingDebugSummary: String? {
        trackingDebugSnapshot?.summary
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var matcher = SpeechProgressMatcher()
    private var isStopping = false
    private var contextualHints: [String] = []
    private var previousHypothesisSegments: [RecognizedSegment] = []
    private var committedSegmentCount = 0
    private var trackingDebugSnapshot: TrackingDebugSnapshot?
    private var stalledFingerprint: String?
    private var stalledCount = 0
    private var stalledNoAdvanceCount = 0
    private var activeRecognitionSessionID = UUID()

    private enum TrackingTuning {
        static let maxContextualHints = 80
        static let minimumSegmentConfidence: Float = 0.35
        static let stalledRepeatThreshold = 3
        static let stalledNoAdvanceThreshold = 2
    }

    func start(
        with text: String,
        localeIdentifier: String = Locale.current.identifier,
        preservingCharCount: Int? = nil,
        contextualHints: [String] = [],
        anchorWordIndex: Int? = nil
    ) {
        stop()
        currentLocaleIdentifier = localeIdentifier
        microphonePermissionDenied = false
        speechPermissionDenied = false
        self.contextualHints = Self.sanitizedHints(contextualHints, limit: TrackingTuning.maxContextualHints)
        if let preservingCharCount {
            matcher.updateText(text, preservingCharCount: preservingCharCount)
        } else {
            matcher.start(with: text)
        }
        if let anchorWordIndex {
            matcher.reanchor(nearWordIndex: anchorWordIndex)
        }
        recognizedCharCount = matcher.recognizedCharCount
        lastSpokenText = ""
        trackingDebugMessage = nil
        trackingDebugSnapshot = nil
        errorMessage = nil
        resetRecognitionStreamState()

        requestPermissionsAndBegin(localeIdentifier: localeIdentifier)
    }

    func stop() {
        isStopping = true
        activeRecognitionSessionID = UUID()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        resetRecognitionStreamState()
        audioLevels = Array(repeating: 0, count: 24)
    }

    func jumpTo(wordIndex: Int, in words: [String]) {
        let charOffset = Self.charOffset(forWordIndex: wordIndex, in: words)
        matcher.jumpTo(charOffset: charOffset)
        matcher.reanchor(nearWordIndex: wordIndex)
        recognizedCharCount = matcher.recognizedCharCount
        trackingDebugMessage = "manual-jump"
        trackingDebugSnapshot = TrackingDebugSnapshot(
            reason: "manual-jump",
            stableSegmentCount: 0,
            committedSegmentCount: committedSegmentCount,
            averageConfidence: nil,
            tailText: nil
        )
        resetRecognitionStreamState()
    }

    func updateText(_ text: String) {
        matcher.updateText(text, preservingCharCount: recognizedCharCount)
        recognizedCharCount = matcher.recognizedCharCount
        trackingDebugMessage = "text-updated"
        trackingDebugSnapshot = TrackingDebugSnapshot(
            reason: "text-updated",
            stableSegmentCount: 0,
            committedSegmentCount: committedSegmentCount,
            averageConfidence: nil,
            tailText: nil
        )
        resetRecognitionStreamState()
    }

    private func requestPermissionsAndBegin(localeIdentifier: String) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            requestSpeechAuthorizationAndBegin(localeIdentifier: localeIdentifier)
        case .denied:
            microphonePermissionDenied = true
            errorMessage = "Microphone permission is denied. Enable it in Settings to use Word Tracking."
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.requestSpeechAuthorizationAndBegin(localeIdentifier: localeIdentifier)
                    } else {
                        self.microphonePermissionDenied = true
                        self.errorMessage = "Microphone permission is required for Word Tracking."
                    }
                }
            }
        @unknown default:
            errorMessage = "Microphone permission is unavailable."
        }
    }

    private func requestSpeechAuthorizationAndBegin(localeIdentifier: String) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginRecognition(localeIdentifier: localeIdentifier)
                case .denied, .restricted:
                    self.speechPermissionDenied = true
                    self.errorMessage = "Speech recognition permission is required for Word Tracking."
                case .notDetermined:
                    self.errorMessage = "Speech recognition permission is still pending. Try again in a moment."
                @unknown default:
                    self.errorMessage = "Speech recognition permission is unavailable."
                }
            }
        }
    }

    private func beginRecognition(localeIdentifier: String) {
        isStopping = false
        let sessionID = UUID()
        activeRecognitionSessionID = sessionID
        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let speechRecognizer else {
            errorMessage = "Speech recognition for \(localeIdentifier) is unavailable on this device."
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is temporarily unavailable for \(localeIdentifier)."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualHints
        request.taskHint = .dictation
        recognitionRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: [])
        } catch {
            errorMessage = "Failed to configure speech audio session: \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            let level = Self.normalizedLevel(from: buffer)
            DispatchQueue.main.async {
                self.audioLevels.append(level)
                if self.audioLevels.count > 24 {
                    self.audioLevels.removeFirst(self.audioLevels.count - 24)
                }
            }
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let segments = self.extractSegments(from: result)
                let spokenText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    guard self.activeRecognitionSessionID == sessionID else { return }
                    self.lastSpokenText = spokenText
                    self.consumeRecognitionResult(segments: segments, spokenText: spokenText, isFinal: result.isFinal)
                }
            }

            if let error {
                DispatchQueue.main.async {
                    guard self.activeRecognitionSessionID == sessionID else { return }
                    if self.isStopping { return }
                    if self.shouldSuppressRecognitionError(error) {
                        self.trackingDebugMessage = "suppressed-recognition-error"
                        self.trackingDebugSnapshot = TrackingDebugSnapshot(
                            reason: "suppressed-recognition-error",
                            stableSegmentCount: 0,
                            committedSegmentCount: self.committedSegmentCount,
                            averageConfidence: nil,
                            tailText: error.localizedDescription
                        )
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    self.isListening = false
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start speech audio engine: \(error.localizedDescription)"
            isListening = false
        }
    }

    private func consumeRecognitionResult(segments: [RecognizedSegment], spokenText: String, isFinal: Bool) {
        let stableSegments = stableSegmentsToCommit(from: segments, isFinal: isFinal)
        if stableSegments.isEmpty {
            let trimmedSpoken = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSpoken.isEmpty {
                let previousCharCount = recognizedCharCount
                let previousTokenIndex = matcher.currentTokenIndex
                let liveDecision = matcher.consumeDecision(spoken: trimmedSpoken)
                trackingDebugMessage = "live-\(liveDecision.reason)"
                trackingDebugSnapshot = TrackingDebugSnapshot(
                    reason: "live-\(liveDecision.reason)",
                    stableSegmentCount: 0,
                    committedSegmentCount: committedSegmentCount,
                    averageConfidence: averageConfidence(for: segments),
                    tailText: trimmedSpoken
                )
                if liveDecision.shouldCommit || liveDecision.charCount > previousCharCount {
                    let monotonicCharCount = max(previousCharCount, liveDecision.charCount)
                    recognizedCharCount = monotonicCharCount
                    if monotonicCharCount > previousCharCount, liveDecision.tokenIndex > previousTokenIndex {
                        resetStallTracking()
                        resetNoAdvanceTracking()
                    } else if matcher.currentTokenIsShort {
                        let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: trimmedSpoken)
                        if futureMatchAdvance > previousCharCount {
                            recognizedCharCount = futureMatchAdvance
                            trackingDebugMessage = "future-word-skip"
                            trackingDebugSnapshot = TrackingDebugSnapshot(
                                reason: "future-word-skip",
                                stableSegmentCount: 0,
                                committedSegmentCount: committedSegmentCount,
                                averageConfidence: averageConfidence(for: segments),
                                tailText: trimmedSpoken
                            )
                            resetStallTracking()
                            resetNoAdvanceTracking()
                        } else if liveDecision.charCount < previousCharCount {
                            trackingDebugMessage = "ignore-backward-reanchor"
                            trackingDebugSnapshot = TrackingDebugSnapshot(
                                reason: "ignore-backward-reanchor",
                                stableSegmentCount: 0,
                                committedSegmentCount: committedSegmentCount,
                                averageConfidence: averageConfidence(for: segments),
                                tailText: trimmedSpoken
                            )
                        }
                    }
                } else {
                    let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: trimmedSpoken)
                    if futureMatchAdvance > previousCharCount {
                        recognizedCharCount = futureMatchAdvance
                        trackingDebugMessage = "future-word-skip"
                        trackingDebugSnapshot = TrackingDebugSnapshot(
                            reason: "future-word-skip",
                            stableSegmentCount: 0,
                            committedSegmentCount: committedSegmentCount,
                            averageConfidence: averageConfidence(for: segments),
                            tailText: trimmedSpoken
                        )
                        resetStallTracking()
                        resetNoAdvanceTracking()
                    } else if shouldForceAdvance(for: trimmedSpoken) || shouldForceAdvanceForNoProgress(spokenText: trimmedSpoken, segments: segments) {
                        let nudged = matcher.nudgeForwardOneToken()
                        if nudged > previousCharCount {
                            recognizedCharCount = nudged
                            trackingDebugMessage = "stall-skip-word"
                            trackingDebugSnapshot = TrackingDebugSnapshot(
                                reason: "stall-skip-word",
                                stableSegmentCount: 0,
                                committedSegmentCount: committedSegmentCount,
                                averageConfidence: averageConfidence(for: segments),
                                tailText: trimmedSpoken
                            )
                            resetStallTracking()
                            resetNoAdvanceTracking()
                        }
                    }
                }
                return
            }

            if isFinal {
                trackingDebugMessage = "final-no-new-segments"
            }
            return
        }

        let previousCharCount = recognizedCharCount
        let previousTokenIndex = matcher.currentTokenIndex
        let decision = matcher.consumeSegments(stableSegments.map(\.text))
        let monotonicCharCount = max(previousCharCount, decision.charCount)
        recognizedCharCount = monotonicCharCount
        trackingDebugMessage = monotonicCharCount > previousCharCount ? decision.reason : "ignore-backward-reanchor"
        trackingDebugSnapshot = TrackingDebugSnapshot(
            reason: monotonicCharCount > previousCharCount ? decision.reason : "ignore-backward-reanchor",
            stableSegmentCount: stableSegments.count,
            committedSegmentCount: committedSegmentCount,
            averageConfidence: averageConfidence(for: stableSegments),
            tailText: stableSegments.suffix(2).map(\.text).joined(separator: " ")
        )
        let tailText = stableSegments.suffix(3).map(\.text).joined(separator: " ")
        if monotonicCharCount > previousCharCount {
            if decision.tokenIndex > previousTokenIndex {
                resetStallTracking()
                resetNoAdvanceTracking()
            } else if matcher.currentTokenIsShort {
                let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: tailText)
                if futureMatchAdvance > previousCharCount {
                    recognizedCharCount = futureMatchAdvance
                    trackingDebugMessage = "future-word-skip"
                    trackingDebugSnapshot = TrackingDebugSnapshot(
                        reason: "future-word-skip",
                        stableSegmentCount: stableSegments.count,
                        committedSegmentCount: committedSegmentCount,
                        averageConfidence: averageConfidence(for: stableSegments),
                        tailText: tailText
                    )
                    resetStallTracking()
                    resetNoAdvanceTracking()
                }
            }
        } else {
            let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: tailText)
            if futureMatchAdvance > previousCharCount {
                recognizedCharCount = futureMatchAdvance
                trackingDebugMessage = "future-word-skip"
                trackingDebugSnapshot = TrackingDebugSnapshot(
                    reason: "future-word-skip",
                    stableSegmentCount: stableSegments.count,
                    committedSegmentCount: committedSegmentCount,
                    averageConfidence: averageConfidence(for: stableSegments),
                    tailText: tailText
                )
                resetStallTracking()
                resetNoAdvanceTracking()
            } else if shouldForceAdvanceForNoProgress(spokenText: spokenText, segments: stableSegments) {
                let nudged = matcher.nudgeForwardOneToken()
                if nudged > previousCharCount {
                    recognizedCharCount = nudged
                    trackingDebugMessage = "stall-skip-word"
                    trackingDebugSnapshot = TrackingDebugSnapshot(
                        reason: "stall-skip-word",
                        stableSegmentCount: stableSegments.count,
                        committedSegmentCount: committedSegmentCount,
                        averageConfidence: averageConfidence(for: stableSegments),
                        tailText: tailText
                    )
                    resetStallTracking()
                    resetNoAdvanceTracking()
                }
            }
        }
    }

    private func stableSegmentsToCommit(from segments: [RecognizedSegment], isFinal: Bool) -> [RecognizedSegment] {
        let stablePrefixCount = commonPrefixCount(previousHypothesisSegments, segments)
        let rawCommitBoundary = isFinal ? segments.count : stablePrefixCount
        let commitBoundary = min(max(0, rawCommitBoundary), segments.count)
        let safeStart = min(committedSegmentCount, segments.count)
        let scanStart = min(safeStart, commitBoundary)

        var confidenceBoundary = commitBoundary
        if !isFinal {
            for index in scanStart..<commitBoundary {
                if !shouldCommit(segment: segments[index]) {
                    confidenceBoundary = index
                    break
                }
            }
        }

        let safeEnd = min(max(0, confidenceBoundary), segments.count)
        let newlyStable = safeEnd > safeStart ? Array(segments[safeStart..<safeEnd]) : []
        previousHypothesisSegments = segments
        committedSegmentCount = max(committedSegmentCount, safeEnd)
        if newlyStable.isEmpty, scanStart < commitBoundary, !isFinal {
            trackingDebugMessage = "hold-low-confidence-segment"
            let blockedSegments = Array(segments[scanStart..<commitBoundary])
            trackingDebugSnapshot = TrackingDebugSnapshot(
                reason: "hold-low-confidence-segment",
                stableSegmentCount: 0,
                committedSegmentCount: committedSegmentCount,
                averageConfidence: averageConfidence(for: blockedSegments),
                tailText: blockedSegments.prefix(2).map(\.text).joined(separator: " ")
            )
        }
        if newlyStable.isEmpty, isFinal {
            trackingDebugSnapshot = TrackingDebugSnapshot(
                reason: "final-no-new-segments",
                stableSegmentCount: 0,
                committedSegmentCount: committedSegmentCount,
                averageConfidence: nil,
                tailText: nil
            )
        }
        return newlyStable
    }

    private func commonPrefixCount(_ lhs: [RecognizedSegment], _ rhs: [RecognizedSegment]) -> Int {
        let upperBound = min(lhs.count, rhs.count)
        var index = 0
        while index < upperBound, lhs[index].fingerprint == rhs[index].fingerprint {
            index += 1
        }
        return index
    }

    private func shouldCommit(segment: RecognizedSegment) -> Bool {
        if segment.fingerprint.count <= 2 {
            return true
        }
        guard let confidence = segment.confidence else { return true }
        return confidence >= TrackingTuning.minimumSegmentConfidence
    }

    private func averageConfidence(for segments: [RecognizedSegment]) -> Float? {
        let confidences = segments.compactMap(\.confidence)
        guard !confidences.isEmpty else { return nil }
        let total = confidences.reduce(0, +)
        return total / Float(confidences.count)
    }

    private func shouldSuppressRecognitionError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("no speech")
            || description.contains("unsuccessful")
            || description.contains("canceled")
            || description.contains("cancelled")
    }

    private func extractSegments(from result: SFSpeechRecognitionResult) -> [RecognizedSegment] {
        result.bestTranscription.segments.compactMap { segment in
            let trimmed = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return RecognizedSegment(
                text: trimmed,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                fingerprint: Self.normalizedFingerprint(text: trimmed)
            )
        }
    }

    private func shouldForceAdvance(for spokenText: String) -> Bool {
        let fingerprint = Self.normalizedFingerprint(text: spokenText)
        guard !fingerprint.isEmpty else {
            resetStallTracking()
            return false
        }
        if fingerprint == stalledFingerprint {
            stalledCount += 1
        } else {
            stalledFingerprint = fingerprint
            stalledCount = 1
        }
        return stalledCount >= TrackingTuning.stalledRepeatThreshold
    }

    private func shouldForceAdvanceForNoProgress(spokenText: String, segments: [RecognizedSegment]) -> Bool {
        let normalizedTokens = spokenText
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        let hasEnoughSignal = normalizedTokens.count >= 2 || segments.count >= 2
        guard hasEnoughSignal else {
            resetNoAdvanceTracking()
            return false
        }
        stalledNoAdvanceCount += 1
        return stalledNoAdvanceCount >= TrackingTuning.stalledNoAdvanceThreshold
    }

    private func resetStallTracking() {
        stalledFingerprint = nil
        stalledCount = 0
    }

    private func resetNoAdvanceTracking() {
        stalledNoAdvanceCount = 0
    }

    private func resetRecognitionStreamState() {
        previousHypothesisSegments = []
        committedSegmentCount = 0
        resetStallTracking()
        resetNoAdvanceTracking()
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var sum: Float = 0
        for index in 0..<frameLength {
            sum += channelData[index] * channelData[index]
        }
        let rms = sqrt(sum / Float(frameLength))
        return Double(min(rms * 6.0, 1.0))
    }

    private static func charOffset(forWordIndex index: Int, in words: [String]) -> Int {
        guard !words.isEmpty else { return 0 }
        let clamped = min(max(index, 0), words.count)
        var offset = 0
        for wordIndex in 0..<clamped {
            offset += words[wordIndex].count + 1
        }
        return offset
    }

    private static func sanitizedHints(_ hints: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for rawHint in hints {
            let hint = rawHint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hint.isEmpty else { continue }
            let key = normalizedFingerprint(text: hint)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            ordered.append(hint)
            if ordered.count >= limit {
                break
            }
        }
        return ordered
    }

    private static func normalizedFingerprint(text: String) -> String {
        text
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

private extension IOSWordTrackingRecognizer {
    struct RecognizedSegment: Equatable {
        let text: String
        let timestamp: TimeInterval
        let duration: TimeInterval
        let confidence: Float?
        let fingerprint: String
    }

    struct TrackingDebugSnapshot {
        let reason: String
        let stableSegmentCount: Int
        let committedSegmentCount: Int
        let averageConfidence: Float?
        let tailText: String?

        var summary: String {
            var parts = [reason, "stable \(stableSegmentCount)", "committed \(committedSegmentCount)"]
            if let averageConfidence {
                parts.append(String(format: "conf %.2f", averageConfidence))
            }
            if let tailText, !tailText.isEmpty {
                parts.append("“\(tailText)”")
            }
            return parts.joined(separator: " · ")
        }
    }
}
