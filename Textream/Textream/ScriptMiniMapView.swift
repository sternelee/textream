//
//  ScriptMiniMapView.swift
//  Textream
//
//  Compact rhythm mini-map showing markup distribution across the script.
//

import SwiftUI

struct ScriptMiniMapView: View {
    let text: String
    let currentCharOffset: Int
    
    private struct RhythmSegment: Identifiable {
        let id = UUID()
        let startRatio: Double // 0.0 - 1.0
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
        let words = splitTextIntoWords(text)
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
            let wordEnd = offset + word.count
            
            // Detect type for this word
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
            
            // If type changes, flush previous segment and start new one
            if type != currentType {
                flushSegment(endOffset: wordStart)
                currentType = type
                segmentStart = wordStart
            }
            
            offset += word.count + 1 // +1 for space
        }
        
        // Flush final segment
        flushSegment(endOffset: offset)
        return result
    }
    
    private var cursorRatio: Double {
        guard text.count > 0 else { return 0 }
        return Double(currentCharOffset) / Double(text.count)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("Rhythm")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                // Legend
                legendDot(color: .yellow, label: "Emph")
                legendDot(color: .blue, label: "Slow")
                legendDot(color: .red, label: "Fast")
                legendDot(color: .gray, label: "Pause")
            }
            
            // Mini-map bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 24)
                    
                    // Segments
                    ForEach(segments) { segment in
                        segmentView(segment, width: geo.size.width)
                    }
                    
                    // Cursor indicator
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 28)
                        .offset(x: cursorRatio * geo.size.width - 1)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(width: 180)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func segmentView(_ segment: RhythmSegment, width: CGFloat) -> some View {
        let x = segment.startRatio * width
        let w = max(1, (segment.endRatio - segment.startRatio) * width)
        
        return Rectangle()
            .fill(segmentColor(segment.type))
            .frame(width: w, height: 20)
            .position(x: x + w/2, y: 12)
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
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }
}
