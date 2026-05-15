//
//  ScriptOutlineView.swift
//  TextreamiOS
//
//  Paragraph-level outline navigation for the current script page.
//

import SwiftUI

struct ScriptOutlineEntry: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let charOffset: Int
    let lineCount: Int
}

struct ScriptOutlineParser {
    static func parseParagraphs(_ text: String) -> [ScriptOutlineEntry] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .enumerated()
            .compactMap { (i, para) -> ScriptOutlineEntry? in
                let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let prefix = text.prefix(text.range(of: para)?.lowerBound.utf16Offset(in: text) ?? 0)
                let charOffset = prefix.count
                let lineCount = para.components(separatedBy: .newlines).count
                let title = extractTitle(from: trimmed)
                return ScriptOutlineEntry(
                    index: i,
                    title: title,
                    charOffset: charOffset,
                    lineCount: lineCount
                )
            }
        return paragraphs
    }

    private static func extractTitle(from text: String) -> String {
        var clean = text
        for tag in ScriptMarkupTag.allCases {
            clean = clean.replacingOccurrences(of: tag.rawValue, with: "")
        }
        clean = clean.replacingOccurrences(of: "**", with: "")
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        let sentenceEnders = CharacterSet(charactersIn: ".!?。！？")
        if let range = clean.rangeOfCharacter(from: sentenceEnders) {
            let sentence = String(clean[..<range.upperBound])
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
            }
        }

        let preview = clean.prefix(40)
        return preview.count > 35 ? String(preview) + "…" : String(preview)
    }

    static func paragraphIndex(at charOffset: Int, in entries: [ScriptOutlineEntry]) -> Int {
        for (i, entry) in entries.enumerated() {
            if i + 1 < entries.count {
                if charOffset >= entry.charOffset && charOffset < entries[i + 1].charOffset {
                    return i
                }
            } else {
                if charOffset >= entry.charOffset {
                    return i
                }
            }
        }
        return 0
    }
}

struct OutlineItemRow: View {
    let index: Int
    let entry: ScriptOutlineEntry
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.35))
                    .frame(width: 20, alignment: .center)

                Text(entry.title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScriptOutlineView: View {
    let text: String
    let currentCharOffset: Int
    let onJump: (Int) -> Void

    @State private var isExpanded = true

    private var entries: [ScriptOutlineEntry] {
        ScriptOutlineParser.parseParagraphs(text)
    }

    private var activeIndex: Int {
        ScriptOutlineParser.paragraphIndex(at: currentCharOffset, in: entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            outlineHeader
            if isExpanded {
                outlineList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var outlineHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Outline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entries.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.primary.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var outlineList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    OutlineItemRow(
                        index: i,
                        entry: entry,
                        isActive: i == activeIndex,
                        onTap: { onJump(entry.charOffset) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 220)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }
}
