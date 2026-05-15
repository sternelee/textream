//
//  PracticeView.swift
//  TextreamiOS
//
//  Practice mode UI: recording, playback, and session reports.
//

import SwiftUI

struct PracticeView: View {
    let scriptText: String
    @Environment(\.dismiss) private var dismiss
    @State private var practiceService = PracticeService.shared
    @State private var showReport = false
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var showSentenceLoop = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showReport, let session = practiceService.currentSession {
                    sessionReportView(session: session)
                } else {
                    recordingControlView
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Practice Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                if !showReport {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSentenceLoop = true
                        } label: {
                            Image(systemName: "repeat")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSentenceLoop) {
                SentenceLoopView(scriptText: scriptText)
            }
            .onDisappear {
                playbackTimer?.invalidate()
            }
        }
    }

    private var recordingControlView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Script preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Script Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(scriptText)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                // Recording button
                VStack(spacing: 16) {
                    if practiceService.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(0.6 + 0.4 * sin(Date().timeIntervalSince1970 * 4))
                            Text("Recording…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        if practiceService.isRecording {
                            practiceService.stopPractice(scriptText: scriptText)
                            showReport = true
                        } else {
                            practiceService.startPractice(scriptText: scriptText)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: practiceService.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(practiceService.isRecording ? "Stop Practice" : "Start Practice")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(practiceService.isRecording ? Color.red : Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    if !practiceService.isRecording {
                        Text("Press to start recording your rehearsal")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
    }

    private func sessionReportView(session: PracticeSession) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreCard(session: session)
                radarChart(session: session)
                statsGrid(session: session)
                WPMChartView(timestamps: session.wordTimestamps, duration: session.duration)
                playbackControls(session: session)
                fillerWordsSection(session: session)
                recognizedTextSection(session: session)
            }
            .padding(16)
        }
    }

    private func scoreCard(session: PracticeSession) -> some View {
        VStack(spacing: 8) {
            Text("\(session.score)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor(session.score))

            Text("Practice Score")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Label("\(Int(session.averageWPM)) WPM", systemImage: "waveform")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(scoreColor(session.score).opacity(0.2), lineWidth: 1.5)
        )
    }

    private func statsGrid(session: PracticeSession) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Pauses", value: "\(session.pauseCount)", icon: "pause.circle")
            statCard(title: "Pause Time", value: String(format: "%.1fs", session.totalPauseTime), icon: "timer")
            statCard(title: "Filler Words", value: "\(session.fillerWordCount)", icon: "exclamationmark.triangle")
            statCard(title: "Avg WPM", value: "\(Int(session.averageWPM))", icon: "speedometer")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func playbackControls(session: PracticeSession) -> some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * playbackProgressFraction, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(practiceService.currentPlaybackTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(practiceService.totalPlaybackDuration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button {
                if practiceService.isPlayingBack {
                    practiceService.stopPlayback()
                    playbackTimer?.invalidate()
                } else {
                    practiceService.startPlayback()
                    startPlaybackTimer()
                }
            } label: {
                Image(systemName: practiceService.isPlayingBack ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var playbackProgressFraction: Double {
        let total = practiceService.totalPlaybackDuration
        guard total > 0 else { return 0 }
        return min(1, practiceService.currentPlaybackTime / total)
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !practiceService.isPlayingBack {
                playbackTimer?.invalidate()
            }
        }
    }

    private func fillerWordsSection(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filler Words Detected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if session.fillerWordCount == 0 {
                Label("None detected — great job!", systemImage: "checkmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            } else {
                Text("Found \(session.fillerWordCount) filler word(s) in your speech.")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func recognizedTextSection(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recognized Speech")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Text(session.recognizedText.isEmpty ? "No speech recognized" : session.recognizedText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func radarChart(session: PracticeSession) -> some View {
        let wpmScore = min(100.0, max(0.0, 100.0 - abs(session.averageWPM - 140.0) / 140.0 * 100.0))
        let pauseScore = min(100.0, max(0.0, 100.0 - Double(session.pauseCount) * 15.0))
        let clarityScore = min(100.0, max(0.0, 100.0 - Double(session.fillerWordCount) * 10.0))
        let timingScore = min(100.0, max(0.0, 100.0 - abs(session.duration - Double(session.scriptText.count) / 700.0) * 20.0))
        let volumeScore = 75.0

        return RadarChartView(dimensions: [
            RadarDimension(label: "Speed", value: wpmScore, icon: "speedometer"),
            RadarDimension(label: "Pauses", value: pauseScore, icon: "pause.circle"),
            RadarDimension(label: "Clarity", value: clarityScore, icon: "waveform"),
            RadarDimension(label: "Timing", value: timingScore, icon: "clock"),
            RadarDimension(label: "Volume", value: volumeScore, icon: "speaker.wave.2")
        ], size: 160)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
