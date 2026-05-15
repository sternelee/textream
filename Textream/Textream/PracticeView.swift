//
//  PracticeView.swift
//  Textream
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice Mode")
                        .font(.system(size: 15, weight: .bold))
                    Text("Record your rehearsal and review the report")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if showReport, let session = practiceService.currentSession {
                sessionReportView(session: session)
            } else {
                recordingControlView
            }
        }
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
        .onDisappear {
            playbackTimer?.invalidate()
        }
    }

    // MARK: - Recording Control

    private var recordingControlView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Script preview
            ScrollView(.vertical, showsIndicators: true) {
                Text(scriptText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 200)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            Spacer()

            // Recording button
            VStack(spacing: 12) {
                if practiceService.isRecording {
                    // Recording indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(0.6 + 0.4 * sin(Date().timeIntervalSince1970 * 4))
                        Text("Recording…")
                            .font(.system(size: 13, weight: .medium))
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
                    HStack(spacing: 6) {
                        Image(systemName: practiceService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(practiceService.isRecording ? "Stop Practice" : "Start Practice")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 160, height: 44)
                    .background(practiceService.isRecording ? Color.red : Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !practiceService.isRecording {
                    Text("Press to start recording your rehearsal")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Session Report

    private func sessionReportView(session: PracticeSession) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                // Score card
                scoreCard(session: session)

                // Stats grid
                statsGrid(session: session)

                // WPM Chart
                WPMChartView(
                    timestamps: session.wordTimestamps,
                    duration: session.duration
                )

                // Playback
                playbackControls(session: session)

                // Filler words
                fillerWordsSection(session: session)

                // Recognized text comparison
                recognizedTextSection(session: session)
            }
            .padding(16)
        }
    }

    private func scoreCard(session: PracticeSession) -> some View {
        VStack(spacing: 8) {
            Text("\(session.score)")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor(session.score))

            Text("Practice Score")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(session.formattedDuration, systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Label("\(Int(session.averageWPM)) WPM", systemImage: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func playbackControls(session: PracticeSession) -> some View {
        VStack(spacing: 10) {
            // Progress bar
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
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(practiceService.totalPlaybackDuration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Filler Words Detected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if session.fillerWordCount == 0 {
                Text("None detected — great job!")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            } else {
                Text("Found \(session.fillerWordCount) filler word(s) in your speech.")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func recognizedTextSection(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recognized Speech")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                Text(session.recognizedText.isEmpty ? "No speech recognized" : session.recognizedText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
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
