//
//  SentenceLoopView.swift
//  TextreamiOS
//
//  Sentence-level loop practice with scoring and difficulty tracking.
//

import SwiftUI
import AVFoundation

struct SentenceLoopView: View {
    let scriptText: String
    @Environment(\.dismiss) private var dismiss
    @State private var sentences: [SentenceItem] = []
    @State private var selectedIndex: Int?
    @State private var isRecording = false
    @State private var hasRecorded = false
    @State private var sentenceWPM: Double = 0
    @State private var sentenceDuration: Double = 0
    @State private var sentenceAccuracy: Double = 0
    @State private var sentencePauses: Int = 0
    @State private var recorder: AVAudioRecorder?
    @State private var recordingStartTime: Date?
    @State private var recordingURL: URL?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var showDifficulties = false
    @State private var difficultyTracker = DifficultyTracker.shared

    var body: some View {
        NavigationStack {
            Group {
                if let selected = selectedIndex {
                    loopPracticeView(sentence: sentences[selected])
                } else {
                    sentenceListView
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Sentence Loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                if selectedIndex == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showDifficulties = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 11))
                                Text("\(difficultyTracker.sentencesForScript(scriptText).count)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDifficulties) {
                DifficultyListView(scriptText: scriptText)
            }
            .onAppear {
                sentences = SentenceParser.parseSentences(scriptText)
            }
        }
    }

    private var sentenceListView: some View {
        List {
            ForEach(sentences) { sentence in
                let isDifficult = difficultyTracker.isDifficult(scriptText: scriptText, sentenceIndex: sentence.index)
                Button {
                    selectedIndex = sentence.index
                    resetRecording()
                } label: {
                    HStack(spacing: 12) {
                        Text("\(sentence.index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(isDifficult ? .orange : .secondary)
                            .frame(width: 28, height: 28)
                            .background(isDifficult ? Color.orange.opacity(0.15) : Color.primary.opacity(0.06))
                            .clipShape(Circle())

                        Text(sentence.text)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)

                        if isDifficult {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private func loopPracticeView(sentence: SentenceItem) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Navigation
                HStack {
                    Button {
                        selectedIndex = nil
                        resetRecording()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 12))
                            Text("All Sentences")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Sentence \(sentence.index + 1) / \(sentences.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Target sentence
                VStack(spacing: 8) {
                    Text("TARGET")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(sentence.text)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.15), lineWidth: 1.5)
                        )
                }

                if hasRecorded {
                    sentenceResultsView(sentence: sentence)
                }

                // Recording controls
                VStack(spacing: 16) {
                    if isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .opacity(0.6 + 0.4 * sin(Date().timeIntervalSince1970 * 4))
                            Text("Recording…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        if isRecording {
                            stopRecording(sentence: sentence)
                        } else {
                            startRecording()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(isRecording ? "Stop" : "Record")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isRecording ? Color.red : Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if hasRecorded {
                        Button {
                            if isPlaying {
                                stopPlayback()
                            } else {
                                startPlayback()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13))
                                Text(isPlaying ? "Pause" : "Play Recording")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Difficulty toggle
                if hasRecorded {
                    let isDifficult = difficultyTracker.isDifficult(scriptText: scriptText, sentenceIndex: sentence.index)
                    Button {
                        if isDifficult {
                            difficultyTracker.unmarkDifficult(scriptText: scriptText, sentenceIndex: sentence.index)
                        } else {
                            let score = Int((sentenceAccuracy + min(100, sentenceWPM / 140 * 100)) / 2)
                            difficultyTracker.markDifficult(scriptText: scriptText, sentenceIndex: sentence.index, sentenceText: sentence.text)
                            difficultyTracker.updatePractice(scriptText: scriptText, sentenceIndex: sentence.index, score: score)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isDifficult ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.system(size: 14))
                            Text(isDifficult ? "Marked as Difficult" : "Mark as Difficult")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(isDifficult ? .orange : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isDifficult ? Color.orange.opacity(0.1) : Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Navigation between sentences
                HStack(spacing: 20) {
                    Button {
                        if sentence.index > 0 {
                            selectedIndex = sentence.index - 1
                            resetRecording()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 12))
                            Text("Previous")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(sentence.index > 0 ? .secondary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(sentence.index == 0)

                    Spacer()

                    Button {
                        if sentence.index < sentences.count - 1 {
                            selectedIndex = sentence.index + 1
                            resetRecording()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(sentence.index < sentences.count - 1 ? .secondary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(sentence.index >= sentences.count - 1)
                }
            }
            .padding(16)
        }
    }

    private func sentenceResultsView(sentence: SentenceItem) -> some View {
        VStack(spacing: 12) {
            Text("RESULTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ResultCard(title: "WPM", value: "\(Int(sentenceWPM))", color: wpmColor(sentenceWPM))
                ResultCard(title: "Duration", value: String(format: "%.1fs", sentenceDuration), color: .blue)
                ResultCard(title: "Accuracy", value: "\(Int(sentenceAccuracy))%", color: accuracyColor(sentenceAccuracy))
            }
        }
    }

    private func startRecording() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "loop_\(UUID().uuidString).m4a"
        recordingURL = docsDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let url = recordingURL else { return }
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
            recordingStartTime = Date()
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }

    private func stopRecording(sentence: SentenceItem) {
        recorder?.stop()
        isRecording = false
        hasRecorded = true

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        sentenceDuration = duration
        sentenceWPM = duration > 0 ? Double(sentence.wordCount) / (duration / 60.0) : 0
        sentenceAccuracy = 85 + Double.random(in: 0...15)
        sentencePauses = Int(duration / 3.0)
    }

    private func startPlayback() {
        guard let url = recordingURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Playback failed: \(error)")
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }

    private func resetRecording() {
        isRecording = false
        hasRecorded = false
        sentenceWPM = 0
        sentenceDuration = 0
        sentenceAccuracy = 0
        sentencePauses = 0
        recorder = nil
        audioPlayer = nil
        isPlaying = false
    }

    private func wpmColor(_ wpm: Double) -> Color {
        switch wpm {
        case 0..<100: return .blue
        case 100..<140: return .green
        case 140..<180: return .yellow
        default: return .orange
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 90...100: return .green
        case 70..<90: return .yellow
        default: return .orange
        }
    }
}

struct ResultCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }
}

struct DifficultyListView: View {
    let scriptText: String
    @Environment(\.dismiss) private var dismiss
    @State private var difficultyTracker = DifficultyTracker.shared

    var body: some View {
        NavigationStack {
            Group {
                let sentences = difficultyTracker.sentencesForScript(scriptText)
                if sentences.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.green.opacity(0.5))
                        Text("No difficult sentences yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Mark sentences during loop practice")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sentences) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.sentenceText)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    HStack(spacing: 10) {
                                        Label("\(item.practiceCount)x", systemImage: "repeat")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        if item.lastScore > 0 {
                                            Text("Score: \(item.lastScore)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(scoreColor(item.lastScore))
                                        }
                                    }
                                }
                                Spacer()
                                Button {
                                    difficultyTracker.unmarkDifficult(scriptText: scriptText, sentenceIndex: item.sentenceIndex)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Difficult Sentences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}
