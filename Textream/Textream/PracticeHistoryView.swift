//
//  PracticeHistoryView.swift
//  Textream
//
//  Browse, review, and replay past practice sessions.
//

import SwiftUI

struct PracticeHistoryView: View {
    @State private var practiceService = PracticeService.shared
    @State private var selectedSession: PracticeSession?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice History")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(practiceService.sessions.count) session(s) recorded")
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
            
            if practiceService.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No practice sessions yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Use Practice mode to record your first rehearsal")
                .font(.system(size: 11))
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
                    .contextMenu {
                        Button(role: .destructive) {
                            practiceService.deleteSession(id: session.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

struct SessionRow: View {
    let session: PracticeSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(scoreColor(session.score).opacity(0.3), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Text("\(session.score)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(session.score))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(session.createdAt, style: .date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Label(session.formattedDuration, systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Label("\(Int(session.averageWPM)) WPM", systemImage: "speedometer")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if session.fillerWordCount > 0 {
                        Label("\(session.fillerWordCount) fillers", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(session.scriptText.prefix(60) + (session.scriptText.count > 60 ? "…" : ""))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}
