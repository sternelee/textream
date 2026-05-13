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

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var matcher = SpeechProgressMatcher()

    func start(with text: String, localeIdentifier: String = Locale.current.identifier, preservingCharCount: Int? = nil) {
        stop()
        if let preservingCharCount {
            matcher.updateText(text, preservingCharCount: preservingCharCount)
            recognizedCharCount = matcher.recognizedCharCount
        } else {
            matcher.start(with: text)
            recognizedCharCount = 0
        }
        lastSpokenText = ""
        errorMessage = nil

        requestPermissionsAndBegin(localeIdentifier: localeIdentifier)
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        audioLevels = Array(repeating: 0, count: 24)
    }

    func jumpTo(wordIndex: Int, in words: [String]) {
        let charOffset = Self.charOffset(forWordIndex: wordIndex, in: words)
        matcher.jumpTo(charOffset: charOffset)
        recognizedCharCount = matcher.recognizedCharCount
    }

    func updateText(_ text: String) {
        matcher.updateText(text, preservingCharCount: recognizedCharCount)
        recognizedCharCount = matcher.recognizedCharCount
    }

    private func requestPermissionsAndBegin(localeIdentifier: String) {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            requestSpeechAuthorizationAndBegin(localeIdentifier: localeIdentifier)
        case .denied:
            errorMessage = "Microphone permission is denied."
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.requestSpeechAuthorizationAndBegin(localeIdentifier: localeIdentifier)
                    } else {
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
                default:
                    self.errorMessage = "Speech recognition permission is required for Word Tracking."
                }
            }
        }
    }

    private func beginRecognition(localeIdentifier: String) {
        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is unavailable."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
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
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.lastSpokenText = spoken
                    self.recognizedCharCount = self.matcher.consume(spoken: spoken)
                }
            }

            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isListening = false
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Failed to start speech audio engine: \(error.localizedDescription)"
            isListening = false
        }
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
}
