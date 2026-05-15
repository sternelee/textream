//
//  ScriptMarkupParser.swift
//  Textream
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
    
    /// Visual representation in the teleprompter
    var displayText: String {
        switch self {
        case .pause:     return "· · ·"
        case .emphasis:  return "▲"
        case .slow:      return "🐢"
        case .fast:      return "🚀"
        case .normal:    return ""
        }
    }
    
    /// Whether this tag acts as a region marker affecting subsequent words
    var isRegionMarker: Bool {
        switch self {
        case .slow, .fast, .normal: return true
        default: return false
        }
    }
    
    /// Color accent for editor highlighting
    var editorColor: Color {
        switch self {
        case .pause:     return Color.gray.opacity(0.6)
        case .emphasis:  return Color.yellow.opacity(0.9)
        case .slow:      return Color.blue.opacity(0.7)
        case .fast:      return Color.red.opacity(0.7)
        case .normal:    return Color.gray.opacity(0.4)
        }
    }
    
    /// Background color for editor highlighting
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
    
    /// Check if a raw word matches a markup tag
    static func tag(for word: String) -> ScriptMarkupTag? {
        ScriptMarkupTag.allCases.first { $0.rawValue == word }
    }
    
    /// Detect if a word is wrapped in **bold**
    static func boldText(from word: String) -> String? {
        guard word.hasPrefix("**"), word.hasSuffix("**"), word.count > 4 else { return nil }
        return String(word.dropFirst(2).dropLast(2))
    }
    
    /// Check if a word is any kind of markup (tag or bold wrapper)
    static func isMarkupWord(_ word: String) -> Bool {
        tag(for: word) != nil || boldText(from: word) != nil
    }
    
    /// Extract display text for a word (removes bold wrappers, converts tags to symbols)
    static func displayText(for word: String) -> String {
        if let tag = tag(for: word) {
            return tag.displayText
        }
        if let bold = boldText(from: word) {
            return bold
        }
        return word
    }
    
    // MARK: - Editor Highlighting
    
    /// Pattern to match all bracket annotations including markup tags
    static let bracketPattern = try! NSRegularExpression(
        pattern: "\\[[^\\]]+\\]",
        options: []
    )
    
    /// Pattern to match **bold** text
    static let boldPattern = try! NSRegularExpression(
        pattern: "\\*\\*([^\\*]+)\\*\\*",
        options: []
    )
    
    /// Get the markup tag for a bracket content string (without brackets)
    static func tagForBracketContent(_ content: String) -> ScriptMarkupTag? {
        ScriptMarkupTag.allCases.first { $0.rawValue == "[\(content)]" }
    }
}
