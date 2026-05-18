//
//  SpeechRecognizer.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import AppKit
import Foundation
import SwiftUI
import Speech
import AVFoundation
import CoreAudio

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String

    static func allInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else { return [] }

        var result: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else { continue }

            // Get UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid) == noErr else { continue }

            // Get name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name) == noErr else { continue }

            result.append(AudioInputDevice(id: deviceID, uid: uid as String, name: name as String))
        }
        return result
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allInputDevices().first(where: { $0.uid == uid })?.id
    }
}

@Observable
class SpeechRecognizer {
    var recognizedCharCount: Int = 0
    var isListening: Bool = false
    /// Lightweight pause: audio buffers are not sent to the recognizer,
    /// timers are suspended. Does NOT tear down the audio engine.
    var isPaused: Bool = false
    var error: String?
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    var lastSpokenText: String = ""
    var shouldDismiss: Bool = false
    var shouldAdvancePage: Bool = false
    
    /// Real-time words-per-minute estimate based on recognized progress
    var currentWPM: Double = 0
    /// WPM history for trend visualization (last 20 samples)
    var wpmHistory: [Double] = []
    private var speechStartTime: Date?
    private var wpmUpdateTimer: Timer?
    
    /// Pause detection: true when user has been silent for too long (potential forgotten line)
    var isLongPause: Bool = false
    /// Estimated time remaining in seconds based on current pace
    var estimatedTimeRemaining: Double = 0
    /// Whether the user is on track to finish within a reasonable time
    var isOnTrack: Bool = true
    private var silenceStartTime: Date?
    private let longPauseThreshold: TimeInterval = 2.5 // seconds
    private let silenceThreshold: CGFloat = 0.03
    private var pauseCheckTimer: Timer?
    
    // MARK: - Word-level pause tracking for phonetic tooltips
    
    /// The word the user is currently stuck on (detected via long pause)
    var currentDifficultWord: String = ""
    /// When the user started pausing on the current word
    var difficultWordStartTime: Date?
    /// Timestamp of when each word was first recognized
    private var wordTimestamps: [(word: String, charOffset: Int, recognizedAt: Date)] = []
    /// Last recognized char count for detecting progress
    private var lastRecognizedCharCount: Int = 0
    /// Timer for detecting per-word pauses
    private var wordPauseTimer: Timer?
    /// Words from source text for lookup
    private var sourceWordsList: [String] = []

    /// True when recent audio levels indicate the user is actively speaking
    var isSpeaking: Bool {
        let recent = audioLevels.suffix(10)
        guard !recent.isEmpty else { return false }
        let avg = recent.reduce(0, +) / CGFloat(recent.count)
        return avg > 0.08
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var sourceText: String = ""
    private var matcher = SpeechProgressMatcher()
    private var retryCount: Int = 0
    private let maxRetries: Int = 10
    private var configurationChangeObserver: Any?
    private var pendingRestart: DispatchWorkItem?
    private var sessionGeneration: Int = 0
    private var suppressConfigChange: Bool = false
    private var requestLock = NSLock()
    private var preemptiveRestartTimer: Timer?
    /// Monotonically increasing ID for each recognition task. Stale error callbacks
    /// from cancelled tasks check this and bail out, preventing cancel → error →
    /// restartTask infinite loops that freeze the main thread.
    private var taskGeneration: UInt64 = 0

    /// Update the source text while preserving the current recognized char count.
    /// Used by Director Mode to live-edit unread text without resetting read progress.
    func updateText(_ text: String, preservingCharCount: Int) {
        matcher.updateText(text, preservingCharCount: preservingCharCount)
        syncSourceStateFromMatcher()
    }

    /// Jump highlight to a specific char offset (e.g. when user taps a word)
    func jumpTo(charOffset: Int) {
        matcher.jumpTo(charOffset: charOffset)
        syncSourceStateFromMatcher()
        retryCount = 0
        if isListening {
            restartRecognition()
        }
    }

    func start(with text: String) {
        // Clean up any previous session immediately so pending restarts
        // and stale taps are removed before the async auth callback fires.
        cleanupRecognition()

        matcher.start(with: text)
        syncSourceStateFromMatcher()
        retryCount = 0
        currentWPM = 0
        wpmHistory = []
        speechStartTime = nil
        currentDifficultWord = ""
        difficultWordStartTime = nil
        wordTimestamps = []
        lastRecognizedCharCount = 0
        error = nil
        sessionGeneration += 1

        // Check microphone permission first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            error = "Microphone access denied. Open System Settings → Privacy & Security → Microphone to allow Textream."
            openMicrophoneSettings()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.requestSpeechAuthAndBegin()
                    } else {
                        self?.error = "Microphone access denied. Open System Settings → Privacy & Security → Microphone to allow Textream."
                    }
                }
            }
            return
        case .authorized:
            break
        @unknown default:
            break
        }

        requestSpeechAuthAndBegin()
    }

    private func requestSpeechAuthAndBegin() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.beginRecognition()
                default:
                    self?.error = "Speech recognition not authorized. Open System Settings → Privacy & Security → Speech Recognition to allow Textream."
                    self?.openSpeechRecognitionSettings()
                }
            }
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openSpeechRecognitionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }

    func stop() {
        isListening = false
        speechStartTime = nil
        stopWPMTimer()
        cleanupRecognition()
    }

    func forceStop() {
        isListening = false
        sourceText = ""
        sourceWordsList = []
        matcher = SpeechProgressMatcher()
        recognizedCharCount = 0
        retryCount = maxRetries
        speechStartTime = nil
        stopWPMTimer()
        cleanupRecognition()
    }

    func resume() {
        retryCount = 0
        matcher.prepareForRestart()
        shouldDismiss = false
        speechStartTime = Date()
        beginRecognition()
    }

    private func cleanupRecognitionTask() {
        // Cancel any pending restart to prevent overlapping beginRecognition calls
        pendingRestart?.cancel()
        pendingRestart = nil

        stopPreemptiveTimer()

        if let observer = configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationChangeObserver = nil
        }
        requestLock.lock()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        requestLock.unlock()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func cleanupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func cleanupRecognition() {
        cleanupRecognitionTask()
        cleanupAudioEngine()
    }

    private func syncSourceStateFromMatcher() {
        sourceText = matcher.sourceText
        sourceWordsList = sourceText.split(separator: " ").map(String.init)
        recognizedCharCount = matcher.recognizedCharCount
    }

    private func contextualStringsForUpcomingText(limit: Int = 50) -> [String] {
        let clampedOffset = min(max(0, recognizedCharCount), sourceText.count)
        let upcoming = String(sourceText.dropFirst(clampedOffset))
        let contextWords = upcoming.split(separator: " ")
            .map { String($0).lowercased().filter { $0.isLetter || $0.isNumber } }
            .filter { $0.count >= 5 }
        return Array(Set(contextWords).prefix(limit))
    }

    /// Coalesces all delayed beginRecognition() calls into a single pending work item.
    /// Any previously scheduled restart is cancelled before the new one is queued.
    private func scheduleBeginRecognition(after delay: TimeInterval) {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRestart = nil
            self.beginRecognition()
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginRecognition() {
        // Ensure clean state
        cleanupRecognition()

        // Create a fresh engine so it picks up the current hardware format.
        // AVAudioEngine caches the device format internally and reset() alone
        // does not reliably flush it after a mic switch.
        audioEngine = AVAudioEngine()

        // Set selected microphone if configured
        let micUID = NotchSettings.shared.selectedMicUID
        if !micUID.isEmpty, let deviceID = AudioInputDevice.deviceID(forUID: micUID) {
            // Suppress config-change observer during our own device switch
            suppressConfigChange = true
            let inputUnit = audioEngine.inputNode.audioUnit
            if let audioUnit = inputUnit {
                var devID = deviceID
                AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &devID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                // Re-initialize audio unit so it picks up the new device's format
                AudioUnitUninitialize(audioUnit)
                AudioUnitInitialize(audioUnit)
            }
            // Allow config changes again after a settle period
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.suppressConfigChange = false
            }
        }

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: NotchSettings.shared.speechLocale))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognizer not available"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        matcher.prepareForRestart()
        syncSourceStateFromMatcher()

        let uniqueContextWords = contextualStringsForUpcomingText()
        if !uniqueContextWords.isEmpty {
            recognitionRequest.contextualStrings = uniqueContextWords
        }

        let inputNode = audioEngine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Guard against invalid format during device transitions (e.g. mic switch)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            // Retry after a longer delay to let the audio system settle
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                error = "Audio input unavailable"
                isListening = false
            }
            return
        }

        // SFSpeechRecognizer requires mono audio. Multi-channel devices (e.g.
        // RODECaster Pro II at 2ch/48kHz) cause the recognition task to silently
        // return no results. Request a mono tap and let AVAudioEngine downmix.
        let monoFormat = AVAudioFormat(
            commonFormat: hardwareFormat.commonFormat,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: hardwareFormat.isInterleaved
        )
        let tapFormat = (hardwareFormat.channelCount > 1) ? monoFormat : hardwareFormat

        // Observe audio configuration changes (e.g. mic switched externally) to restart gracefully
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.suppressConfigChange, !self.sourceText.isEmpty else { return }
            self.restartRecognition()
        }

        // Belt-and-suspenders: ensure no stale tap exists before installing
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            self?.appendBufferToRequest(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            let level = CGFloat(min(rms * 5, 1.0))

            DispatchQueue.main.async {
                self?.audioLevels.append(level)
                if (self?.audioLevels.count ?? 0) > 30 {
                    self?.audioLevels.removeFirst()
                }
            }
        }

        let currentGeneration = sessionGeneration
        let thisTaskGen = taskGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    // Ignore stale results from a previous session or restarted task
                    guard self.sessionGeneration == currentGeneration,
                          self.taskGeneration == thisTaskGen else { return }
                    self.retryCount = 0 // Reset on success
                    self.lastSpokenText = spoken
                    self.matchCharacters(spoken: spoken)
                }
            }
            if let error {
                DispatchQueue.main.async {
                    // Ignore errors from stale/replaced tasks
                    guard self.taskGeneration == thisTaskGen else { return }
                    // If recognitionRequest is nil, cleanup already ran (intentional cancel)
                    guard self.recognitionRequest != nil else { return }
                    guard self.isListening && !self.shouldDismiss && !self.sourceText.isEmpty else {
                        self.isListening = false
                        return
                    }

                    self.matcher.prepareForRestart()
                    self.syncSourceStateFromMatcher()

                    // Distinguish timeout errors (expected every ~60s) from real errors.
                    // SFSpeechRecognizer timeout is error code 1110 in kAFAssistantErrorDomain,
                    // or 216 (kAudioConverterErr_FormatNotSupported). Retry immediately for
                    // timeouts with no retry limit; use backoff for real errors.
                    let nsError = error as NSError
                    let isTimeout = nsError.code == 1110 || nsError.code == 216

                    if isTimeout {
                        // Expected timeout — restart immediately, no retry limit
                        self.retryCount = 0
                        if self.audioEngine.isRunning {
                            self.restartTask()
                        } else {
                            self.scheduleBeginRecognition(after: 0.1)
                        }
                    } else if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        let delay = min(Double(self.retryCount) * 0.5, 1.5)
                        self.scheduleBeginRecognition(after: delay)
                    } else {
                        self.isListening = false
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            speechStartTime = Date()
            startWPMTimer()
            startPreemptiveTimer()
        } catch {
            // Transient failure after a device switch — retry with longer delay
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                self.error = "Audio engine failed: \(error.localizedDescription)"
                isListening = false
            }
        }
    }

    private func restartRecognition() {
        retryCount = 0
        isListening = true
        if audioEngine.isRunning {
            restartTask()
        } else {
            cleanupRecognition()
            scheduleBeginRecognition(after: 0.5)
        }
    }

    // MARK: - Thread-safe buffer appending

    private func appendBufferToRequest(_ buffer: AVAudioPCMBuffer) {
        guard !isPaused else { return }   // drop buffers while paused
        requestLock.lock()
        recognitionRequest?.append(buffer)
        requestLock.unlock()
    }

    /// Pause speech recognition without tearing down the audio engine.
    func pauseRecognition() {
        guard isListening, !isPaused else { return }
        isPaused = true
        // Freeze WPM / pause-detection timers so they don't drift
        wpmUpdateTimer?.invalidate()
        wpmUpdateTimer = nil
        pauseCheckTimer?.invalidate()
        pauseCheckTimer = nil
        stopWordPauseTimer()
        silenceStartTime = nil
        isLongPause = false
        // NOTE: do NOT clear currentDifficultWord here — doing so triggers
        // onChange(of: currentDifficultWord) which would immediately dismiss
        // the phonetic tooltip we're about to show.
    }

    /// Resume speech recognition after a lightweight pause.
    func unpauseRecognition() {
        guard isPaused else { return }
        isPaused = false
        // Clear the difficult word so the same word doesn't re-trigger a tooltip
        currentDifficultWord = ""
        difficultWordStartTime = nil
        // Restart timers only if we are still actively listening
        if isListening {
            speechStartTime = speechStartTime ?? Date()
            startWPMTimer()
        }
    }

    // MARK: - Soft restart (task only, keeps audio engine running)

    private func restartTask() {
        // Bump generation so stale callbacks from the old task are ignored
        taskGeneration += 1
        matcher.prepareForRestart()
        syncSourceStateFromMatcher()

        // Cancel any pending restart to avoid stale beginRecognition clobbering this session
        pendingRestart?.cancel()
        pendingRestart = nil

        // Cancel the old task and atomically swap to a new request under lock.
        // The lock prevents the audio tap from appending to the old request
        // between endAudio() and the new assignment.
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true

        let uniqueWords = contextualStringsForUpcomingText()
        if !uniqueWords.isEmpty {
            newRequest.contextualStrings = uniqueWords
        }

        // Nil out recognitionRequest before cancelling the old task so the
        // old task's error callback sees nil and skips retry logic. Then set
        // the new request after cancellation.
        requestLock.lock()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        requestLock.unlock()
        recognitionTask?.cancel()
        recognitionTask = nil

        requestLock.lock()
        recognitionRequest = newRequest
        requestLock.unlock()

        // Start new recognition task
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognizer not available"
            isListening = false
            return
        }

        let currentGeneration = sessionGeneration
        let thisTaskGen = taskGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    // Ignore stale results from a different session or restarted task
                    guard self.sessionGeneration == currentGeneration,
                          self.taskGeneration == thisTaskGen else { return }
                    self.retryCount = 0
                    self.lastSpokenText = spoken
                    self.matchCharacters(spoken: spoken)
                }
            }
            if let error {
                DispatchQueue.main.async {
                    // Ignore errors from stale/replaced tasks — a new generation means
                    // we intentionally cancelled this one and shouldn't restart on its behalf
                    guard self.taskGeneration == thisTaskGen else { return }
                    guard self.recognitionRequest != nil else { return }
                    guard self.isListening && !self.shouldDismiss && !self.sourceText.isEmpty else {
                        self.isListening = false
                        return
                    }

                    self.matcher.prepareForRestart()
                    self.syncSourceStateFromMatcher()

                    let nsError = error as NSError
                    let isTimeout = nsError.code == 1110 || nsError.code == 216

                    if isTimeout {
                        self.retryCount = 0
                        if self.audioEngine.isRunning {
                            self.restartTask()
                        } else {
                            self.scheduleBeginRecognition(after: 0.1)
                        }
                    } else if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        let delay = min(Double(self.retryCount) * 0.5, 1.5)
                        self.scheduleBeginRecognition(after: delay)
                    } else {
                        self.isListening = false
                    }
                }
            }
        }

        startPreemptiveTimer()
    }

    // MARK: - Pre-emptive restart timer

    private func startPreemptiveTimer() {
        preemptiveRestartTimer?.invalidate()
        preemptiveRestartTimer = Timer.scheduledTimer(withTimeInterval: 55.0, repeats: true) { [weak self] _ in
            guard let self, self.isListening, !self.sourceText.isEmpty else { return }
            self.restartTask()
        }
    }

    private func stopPreemptiveTimer() {
        preemptiveRestartTimer?.invalidate()
        preemptiveRestartTimer = nil
    }
    
    // MARK: - WPM Tracking
    
    private func startWPMTimer() {
        wpmUpdateTimer?.invalidate()
        wpmUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateWPM()
        }
        pauseCheckTimer?.invalidate()
        pauseCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPauseAndPacing()
        }
        startWordPauseTimer()
    }
    
    private func stopWPMTimer() {
        wpmUpdateTimer?.invalidate()
        wpmUpdateTimer = nil
        pauseCheckTimer?.invalidate()
        pauseCheckTimer = nil
        stopWordPauseTimer()
    }
    
    private func checkPauseAndPacing() {
        guard !sourceText.isEmpty else { return }
        let recent = audioLevels.suffix(20)
        let avgLevel = recent.isEmpty ? 0 : recent.reduce(0, +) / CGFloat(recent.count)
        
        // Silence detection
        if avgLevel < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let start = silenceStartTime, Date().timeIntervalSince(start) > longPauseThreshold {
                isLongPause = true
            }
        } else {
            silenceStartTime = nil
            isLongPause = false
        }
        
        // Pacing estimation
        let remainingChars = max(0, sourceText.count - recognizedCharCount)
        if currentWPM > 10, remainingChars > 0 {
            let estimatedMinutes = Double(remainingChars) / 5.0 / currentWPM
            estimatedTimeRemaining = estimatedMinutes * 60.0
            // Assume 30s per slide/page as target
            isOnTrack = estimatedTimeRemaining < 60.0
        } else {
            estimatedTimeRemaining = 0
            isOnTrack = true
        }
    }
    
    private func updateWPM() {
        guard let startTime = speechStartTime, recognizedCharCount > 0 else {
            currentWPM = 0
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 0 else { return }
        // Estimate word count from characters (avg 5 chars per word)
        let estimatedWords = Double(recognizedCharCount) / 5.0
        let wpm = estimatedWords / (elapsed / 60.0)
        currentWPM = wpm
        wpmHistory.append(wpm)
        if wpmHistory.count > 20 {
            wpmHistory.removeFirst()
        }
    }
    
    // MARK: - Per-word pause detection for phonetic tooltips
    
    private func startWordPauseTimer() {
        wordPauseTimer?.invalidate()
        wordPauseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkWordPause()
        }
    }
    
    private func stopWordPauseTimer() {
        wordPauseTimer?.invalidate()
        wordPauseTimer = nil
    }
    
    private func checkWordPause() {
        guard NotchSettings.shared.phoneticTooltipEnabled,
              !sourceWordsList.isEmpty else { return }
        
        let threshold = NotchSettings.shared.pauseThreshold
        
        // If no progress has been made since last check and we're in a pause
        if recognizedCharCount == lastRecognizedCharCount {
            if let pauseStart = silenceStartTime {
                let pauseDuration = Date().timeIntervalSince(pauseStart)
                if pauseDuration >= threshold {
                    // Find the current word at the pause position
                    let word = findWordAt(charOffset: recognizedCharCount)
                    if !word.isEmpty && word != currentDifficultWord {
                        currentDifficultWord = word
                        difficultWordStartTime = pauseStart
                    }
                }
            }
        } else {
            // Progress was made, record timestamp for the newly recognized words
            recordWordTimestamps()
            // Clear difficult word if progress resumes
            if currentDifficultWord.isEmpty == false {
                currentDifficultWord = ""
                difficultWordStartTime = nil
            }
        }
        lastRecognizedCharCount = recognizedCharCount
    }
    
    /// Find the word at a given character offset
    func findWordAt(charOffset: Int) -> String {
        var offset = 0
        for word in sourceWordsList {
            let wordEnd = offset + word.count
            if charOffset >= offset && charOffset <= wordEnd {
                // Skip markup tags and annotations
                if ScriptMarkupParser.tag(for: word) != nil { return "" }
                if word.hasPrefix("[") && word.hasSuffix("]") { return "" }
                // Strip trailing punctuation for cleaner lookup
                let stripped = word.trimmingCharacters(in: CharacterSet.punctuationCharacters)
                guard !stripped.isEmpty else { return "" }
                // Strip bold wrapper
                if let boldText = ScriptMarkupParser.boldText(from: stripped) {
                    return boldText
                }
                return stripped
            }
            offset = wordEnd + 1 // +1 for space
        }
        return ""
    }
    
    /// Record timestamps for newly recognized words
    private func recordWordTimestamps() {
        guard let startTime = speechStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        
        var offset = 0
        for word in sourceWordsList {
            let wordEnd = offset + word.count
            // If this word was newly recognized (its end is within the recognized range)
            if wordEnd <= recognizedCharCount {
                let alreadyRecorded = wordTimestamps.contains { $0.charOffset == offset }
                if !alreadyRecorded {
                    wordTimestamps.append((word: word, charOffset: offset, recognizedAt: Date(timeInterval: -elapsed + Double(wordEnd) / Double(max(1, sourceText.count)) * elapsed, since: startTime)))
                }
            }
            offset = wordEnd + 1
        }
    }
    
    /// Overall status color for the teleprompter indicator (combines WPM + pause + pacing)
    var statusColor: Color {
        if isLongPause { return .cyan }
        if !isOnTrack { return .pink }
        return wpmStatusColor
    }
    
    /// WPM status color for visual feedback
    var wpmStatusColor: Color {
        switch currentWPM {
        case 0: return .gray
        case ..<100: return .blue
        case 100..<120: return .green
        case 120..<160: return .yellow
        case 160..<200: return .orange
        default: return .red
        }
    }

    // MARK: - Shared matcher-driven progress

    private func matchCharacters(spoken: String) {
        let trimmedSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSpoken.isEmpty else { return }

        let previousCharCount = recognizedCharCount
        let previousTokenIndex = matcher.currentTokenIndex
        let decision = matcher.consumeDecision(spoken: trimmedSpoken)
        var nextCharCount = decision.charCount

        if nextCharCount > previousCharCount {
            if decision.tokenIndex <= previousTokenIndex && matcher.currentTokenIsShort {
                let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: trimmedSpoken)
                nextCharCount = max(nextCharCount, futureMatchAdvance)
            }
        } else {
            let futureMatchAdvance = matcher.advanceToFutureMatchingToken(using: trimmedSpoken)
            nextCharCount = max(nextCharCount, futureMatchAdvance)

            if nextCharCount < previousCharCount {
                matcher.updateText(sourceText, preservingCharCount: previousCharCount)
                nextCharCount = previousCharCount
            }
        }

        recognizedCharCount = max(previousCharCount, nextCharCount)
    }
}
