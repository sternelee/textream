//
//  ResumePromptView.swift
//  Textream
//
//  Prompt to resume reading from last position.
//

import SwiftUI

enum ResumeAction {
    case resume
    case restart
}

struct ResumePromptView: View {
    let progress: ReadingProgress
    let onAction: (ResumeAction) -> Void

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(progress.timestamp)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60)) 分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600)) 小时前" }
        return "\(Int(interval / 86400)) 天前"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "bookmark.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.accentColor)

            // Title
            Text("继续上次的演讲？")
                .font(.system(size: 17, weight: .bold))

            // Details
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("📄 第 \(progress.pageIndex + 1) 页")
                        .font(.system(size: 13))
                    if progress.pageCount > 1 {
                        Text("/ 共 \(progress.pageCount) 页")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                if !progress.wordSnippet.isEmpty {
                    Text("“\(progress.wordSnippet)”")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Text(timeAgo)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Actions
            HStack(spacing: 10) {
                Button("从头开始") {
                    onAction(.restart)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("继续阅读") {
                    onAction(.resume)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}

