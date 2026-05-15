//
//  PracticeHistoryView.swift
//  TextreamiOS
//
//  Browse, review, and replay past practice sessions.
//

import SwiftUI

struct PracticeHistoryView: View {
    @State private var practiceService = PracticeService.shared
    @State private var selectedSession: PracticeSession?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if practiceService.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Practice History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedSession) { session in
                PracticeSessionDetailView(session: session)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mic.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No practice sessions yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Use Practice mode to record your first rehearsal")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var sessionList: some View {
        List {
            ForEach(practiceService.sessions) { session in
                SessionRow(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                        practiceService.currentSession = session
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    practiceService.deleteSession(id: practiceService.sessions[index].id)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct SessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(scoreColor(session.score).opacity(0.3), lineWidth: 3)
                    .frame(width: 48, height: 48)
                Text("\(session.score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(session.score))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.createdAt, style: .date)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 10) {
                    Label(session.formattedDuration, systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Label("\(Int(session.averageWPM)) WPM", systemImage: "speedometer")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if session.fillerWordCount > 0 {
                        Label("\(session.fillerWordCount) fillers", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }

                Text(session.scriptText.prefix(60) + (session.scriptText.count > 60 ? "…" : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct PracticeSessionDetailView: View {
    let session: PracticeSession
    @Environment(\.dismiss) private var dismiss
    @State private var practiceService = PracticeService.shared
    @State private var playbackTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score
                    VStack(spacing: 8) {
                        Text("\(session.score)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundStyle(scoreColor(session.score))
                        Text("Practice Score")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    // Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Duration", value: session.formattedDuration, icon: "clock")
                        StatCard(title: "Avg WPM", value: "\(Int(session.averageWPM))", icon: "speedometer")
                        StatCard(title: "Pauses", value: "\(session.pauseCount)", icon: "pause.circle")
                        StatCard(title: "Fillers", value: "\(session.fillerWordCount)", icon: "exclamationmark.triangle")
                    }

                    // WPM Chart
                    WPMChartView(timestamps: session.wordTimestamps, duration: session.duration)

                    // Playback
                    if session.recordingURL != nil {
                        playbackSection
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear {
                playbackTimer?.invalidate()
                practiceService.stopPlayback()
            }
        }
    }

    private var playbackSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(formatTime(practiceService.currentPlaybackTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(practiceService.totalPlaybackDuration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button {
                if practiceService.isPlayingBack {
                    practiceService.stopPlayback()
                    playbackTimer?.invalidate()
                } else {
                    practiceService.currentSession = session
                    practiceService.startPlayback()
                    startPlaybackTimer()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: practiceService.isPlayingBack ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(practiceService.isPlayingBack ? "Pause" : "Play Recording")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if !practiceService.isPlayingBack {
                playbackTimer?.invalidate()
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

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
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
}
