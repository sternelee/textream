//
//  PracticeService.swift
//  Textream
//
//  Manages practice recording, speech recognition, and session data.
//

import Foundation
import AVFoundation

@Observable
class PracticeService {
    static let shared = PracticeService()
    
    var isRecording = false
    var isPlayingBack = false
    var currentSession: PracticeSession?
    var sessions: [PracticeSession] = []
    
    // Recording
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    
    // Playback
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    // Speech tracking during practice
    private var wordTimestamps: [WordTimestamp] = []
    private var lastRecognizedCharCount = 0
    private var speechRecognizer: SpeechRecognizer?
    
    // Filler words to detect
    static let fillerWords = ["um", "uh", "like", "you know", "so", "well", "actually", "basically", "literally", "然后", "那个", "就是", "嗯", "啊"]
    
    private init() {
        loadSessions()
    }
    
    // MARK: - Recording
    
    func startPractice(scriptText: String) {
        guard !isRecording else { return }
        
        // Create recording file
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "practice_\(UUID().uuidString).m4a"
        recordingURL = docsDir.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        guard let url = recordingURL else { return }
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
        } catch {
            print("Recorder setup failed: \(error)")
            return
        }
        
        // Start recording
        audioRecorder?.record()
        recordingStartTime = Date()
        wordTimestamps = []
        lastRecognizedCharCount = 0
        isRecording = true
        
        // Start speech recognition
        speechRecognizer = SpeechRecognizer()
        speechRecognizer?.start(with: scriptText)
    }
    
    func stopPractice(scriptText: String) {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let recognized = speechRecognizer?.lastSpokenText ?? ""
        
        // Build word timestamps from speech recognizer data
        let timestamps = buildWordTimestamps(scriptText: scriptText)
        
        // Count filler words
        let fillerCount = countFillerWords(in: recognized)
        
        // Calculate average WPM
        let wordCount = scriptText.split(separator: " ").count
        let wpm = duration > 0 ? Double(wordCount) / (duration / 60.0) : 0
        
        // Count pauses (gaps > 0.8s between words)
        let (pauseCount, pauseTime) = analyzePauses(timestamps: timestamps)
        
        let session = PracticeSession(
            id: UUID(),
            createdAt: Date(),
            scriptText: scriptText,
            recordingURL: recordingURL,
            duration: duration,
            wordTimestamps: timestamps,
            recognizedText: recognized,
            averageWPM: wpm,
            pauseCount: pauseCount,
            totalPauseTime: pauseTime,
            fillerWordCount: fillerCount
        )
        
        currentSession = session
        sessions.insert(session, at: 0)
        saveSessions()
        
        speechRecognizer?.stop()
        speechRecognizer = nil
    }
    
    // MARK: - Playback
    
    func startPlayback() {
        guard let url = currentSession?.recordingURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlayingBack = true
            
            playbackTimer?.invalidate()
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                if self?.audioPlayer?.isPlaying == false {
                    self?.stopPlayback()
                }
            }
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlayingBack = false
    }
    
    var currentPlaybackTime: Double {
        audioPlayer?.currentTime ?? 0
    }
    
    var totalPlaybackDuration: Double {
        audioPlayer?.duration ?? 0
    }
    
    // MARK: - Analysis
    
    private func buildWordTimestamps(scriptText: String) -> [WordTimestamp] {
        // Simplified: create timestamps based on char progress and total duration
        let words = splitTextIntoWords(scriptText)
        let totalDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 1
        var result: [WordTimestamp] = []
        var offset = 0
        
        for (_, word) in words.enumerated() {
            let progress = Double(offset) / Double(max(1, scriptText.count))
            let start = progress * totalDuration
            let end = (Double(offset + word.count) / Double(max(1, scriptText.count))) * totalDuration
            result.append(WordTimestamp(
                word: word,
                startTime: start,
                endTime: end,
                charOffset: offset
            ))
            offset += word.count + 1
        }
        return result
    }
    
    private func countFillerWords(in text: String) -> Int {
        let lower = text.lowercased()
        return PracticeService.fillerWords.reduce(0) { count, filler in
            count + lower.components(separatedBy: filler).count - 1
        }
    }
    
    private func analyzePauses(timestamps: [WordTimestamp]) -> (count: Int, totalTime: Double) {
        var pauseCount = 0
        var pauseTime = 0.0
        for i in 1..<timestamps.count {
            let gap = timestamps[i].startTime - timestamps[i-1].endTime
            if gap > 0.8 {
                pauseCount += 1
                pauseTime += gap
            }
        }
        return (pauseCount, pauseTime)
    }
    
    // MARK: - Persistence
    
    private var sessionsFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("practice_sessions.json")
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL)
        } catch {
            print("Save sessions failed: \(error)")
        }
    }
    
    private func loadSessions() {
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            sessions = try JSONDecoder().decode([PracticeSession].self, from: data)
        } catch {
            sessions = []
        }
    }
    
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        saveSessions()
    }
}
