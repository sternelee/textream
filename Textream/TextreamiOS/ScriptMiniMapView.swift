//
//  ScriptMiniMapView.swift
//  TextreamiOS
//
//  Compact rhythm mini-map showing markup distribution across the script.
//

import SwiftUI

struct ScriptMiniMapView: View {
    let text: String
    let currentCharOffset: Int

    private struct RhythmSegment: Identifiable {
        let id = UUID()
        let startRatio: Double
        let endRatio: Double
        let type: SegmentType

        enum SegmentType {
            case normal
            case pause
            case emphasis
            case slow
            case fast
            case bold
        }
    }

    private var segments: [RhythmSegment] {
        let words = TextSegmentation.splitIntoWords(text)
        guard !words.isEmpty else { return [] }

        var result: [RhythmSegment] = []
        var offset = 0
        var currentType: RhythmSegment.SegmentType = .normal
        var segmentStart = 0

        func flushSegment(endOffset: Int) {
            let total = max(1, text.count)
            let startRatio = Double(segmentStart) / Double(total)
            let endRatio = Double(endOffset) / Double(total)
            result.append(RhythmSegment(
                startRatio: startRatio,
                endRatio: endRatio,
                type: currentType
            ))
        }

        for word in words {
            let wordStart = offset
            let type: RhythmSegment.SegmentType
            if let tag = ScriptMarkupParser.tag(for: word) {
                switch tag {
                case .pause: type = .pause
                case .emphasis: type = .emphasis
                case .slow: type = .slow
                case .fast: type = .fast
                default: type = .normal
                }
            } else if ScriptMarkupParser.boldText(from: word) != nil {
                type = .bold
            } else {
                type = .normal
            }

            if type != currentType {
                flushSegment(endOffset: wordStart)
                currentType = type
                segmentStart = wordStart
            }

            offset += word.count + 1
        }

        flushSegment(endOffset: offset)
        return result
    }

    private var cursorRatio: Double {
        guard text.count > 0 else { return 0 }
        return Double(currentCharOffset) / Double(text.count)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("Rhythm")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                legendDot(color: .yellow, label: "Emph")
                legendDot(color: .blue, label: "Slow")
                legendDot(color: .red, label: "Fast")
                legendDot(color: .gray, label: "Pause")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 20)

                    ForEach(segments) { segment in
                        segmentView(segment, width: geo.size.width)
                    }

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 24)
                        .offset(x: cursorRatio * geo.size.width - 1)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func segmentView(_ segment: RhythmSegment, width: CGFloat) -> some View {
        let x = segment.startRatio * width
        let w = max(1, (segment.endRatio - segment.startRatio) * width)

        return Rectangle()
            .fill(segmentColor(segment.type))
            .frame(width: w, height: 16)
            .position(x: x + w/2, y: 10)
    }

    private func segmentColor(_ type: RhythmSegment.SegmentType) -> Color {
        switch type {
        case .normal:  return Color.primary.opacity(0.08)
        case .pause:   return Color.gray.opacity(0.25)
        case .emphasis: return Color.yellow.opacity(0.35)
        case .slow:    return Color.blue.opacity(0.25)
        case .fast:    return Color.red.opacity(0.25)
        case .bold:    return Color.accentColor.opacity(0.2)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
}
