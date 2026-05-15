//
//  ScriptMarkupParser.swift
//  TextreamiOS
//
//  Script markup tag definitions and parsing for rich-text teleprompter rendering.
//  Supports: [pause], [emphasis], [slow], [fast], [normal], **bold**
//

import Foundation
import SwiftUI

// MARK: - Markup Tags

enum ScriptMarkupTag: String, CaseIterable {
    case pause = "[pause]"
    case emphasis = "[emphasis]"
    case slow = "[slow]"
    case fast = "[fast]"
    case normal = "[normal]"

    var displayText: String {
        switch self {
        case .pause:     return "· · ·"
        case .emphasis:  return "▲"
        case .slow:      return "🐢"
        case .fast:      return "🚀"
        case .normal:    return ""
        }
    }

    var isRegionMarker: Bool {
        switch self {
        case .slow, .fast, .normal: return true
        default: return false
        }
    }

    var editorColor: Color {
        switch self {
        case .pause:     return Color.gray.opacity(0.6)
        case .emphasis:  return Color.yellow.opacity(0.9)
        case .slow:      return Color.blue.opacity(0.7)
        case .fast:      return Color.red.opacity(0.7)
        case .normal:    return Color.gray.opacity(0.4)
        }
    }

    var editorBackground: Color {
        switch self {
        case .pause:     return Color.gray.opacity(0.08)
        case .emphasis:  return Color.yellow.opacity(0.15)
        case .slow:      return Color.blue.opacity(0.10)
        case .fast:      return Color.red.opacity(0.10)
        case .normal:    return Color.clear
        }
    }
}

// MARK: - Rhythm Hint

enum RhythmHint {
    case slow
    case fast
    case normal

    var overlayBackground: Color {
        switch self {
        case .slow:  return Color.blue.opacity(0.06)
        case .fast:  return Color.red.opacity(0.06)
        case .normal: return Color.clear
        }
    }

    var editorBackground: Color {
        switch self {
        case .slow:  return Color.blue.opacity(0.08)
        case .fast:  return Color.red.opacity(0.08)
        case .normal: return Color.clear
        }
    }
}

// MARK: - Word Style

struct WordStyle {
    var isBold: Bool = false
    var isEmphasis: Bool = false
    var isPauseMarker: Bool = false
    var rhythmHint: RhythmHint?
}

// MARK: - Parser

struct ScriptMarkupParser {

    static func tag(for word: String) -> ScriptMarkupTag? {
        ScriptMarkupTag.allCases.first { $0.rawValue == word }
    }

    static func boldText(from word: String) -> String? {
        guard word.hasPrefix("**"), word.hasSuffix("**"), word.count > 4 else { return nil }
        return String(word.dropFirst(2).dropLast(2))
    }

    static func isMarkupWord(_ word: String) -> Bool {
        tag(for: word) != nil || boldText(from: word) != nil
    }

    static func displayText(for word: String) -> String {
        if let tag = tag(for: word) {
            return tag.displayText
        }
        if let bold = boldText(from: word) {
            return bold
        }
        return word
    }

    static let bracketPattern = try! NSRegularExpression(
        pattern: "\\[[^\\]]+\\]",
        options: []
    )

    static let boldPattern = try! NSRegularExpression(
        pattern: "\\*\\*([^\\*]+)\\*\\*",
        options: []
    )

    static func tagForBracketContent(_ content: String) -> ScriptMarkupTag? {
        ScriptMarkupTag.allCases.first { $0.rawValue == "[\(content)]" }
    }
}
