//
//  SentenceParser.swift
//  Textream
//
//  Split script text into sentences for loop practice.
//

import Foundation

struct SentenceItem: Identifiable {
    let id = UUID()
    let index: Int
    let text: String
    let charOffset: Int
    let charEnd: Int
    let wordCount: Int
}

struct SentenceParser {
    /// Split text into sentences, preserving markup tags within sentences
    static func parseSentences(_ text: String) -> [SentenceItem] {
        guard !text.isEmpty else { return [] }
        
        var sentences: [SentenceItem] = []
        var currentStart = 0
        var sentenceIndex = 0
        
        let sentenceEnders = CharacterSet(charactersIn: ".!?。！？")
        let chars = Array(text)
        
        for i in 0..<chars.count {
            let char = chars[i]
            
            // Check for sentence-ending punctuation
            if String(char).rangeOfCharacter(from: sentenceEnders) != nil {
                // Look ahead to see if this is actually a sentence end
                // (not part of an abbreviation like "e.g." or "Dr.")
                let isAbbreviation = isAbbreviationEnding(at: i, in: text)
                if !isAbbreviation {
                    let endIndex = i + 1
                    let sentenceText = String(text[text.index(text.startIndex, offsetBy: currentStart)..<text.index(text.startIndex, offsetBy: endIndex)])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !sentenceText.isEmpty {
                        let words = sentenceText.split(separator: " ").count
                        sentences.append(SentenceItem(
                            index: sentenceIndex,
                            text: sentenceText,
                            charOffset: currentStart,
                            charEnd: endIndex,
                            wordCount: words
                        ))
                        sentenceIndex += 1
                    }
                    currentStart = endIndex
                }
            }
        }
        
        // Add remaining text as last sentence
        if currentStart < text.count {
            let remaining = String(text.dropFirst(currentStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                let words = remaining.split(separator: " ").count
                sentences.append(SentenceItem(
                    index: sentenceIndex,
                    text: remaining,
                    charOffset: currentStart,
                    charEnd: text.count,
                    wordCount: words
                ))
            }
        }
        
        return sentences
    }
    
    /// Check if the period at position is part of a known abbreviation
    private static func isAbbreviationEnding(at position: Int, in text: String) -> Bool {
        let abbreviations = ["mr.", "mrs.", "dr.", "prof.", "e.g.", "i.e.", "vs.", "etc.", "inc.", "ltd.", "corp.", "st.", "ave.", "blvd.", "no.", "vol.", "chap.", "fig.", "et al.", "ph.d.", "m.d.", "b.a.", "m.a.", "u.s.", "u.k.", "e.u.", "a.m.", "p.m."]
        
        let prefixLength = min(position + 1, 10)
        let startIndex = text.index(text.startIndex, offsetBy: max(0, position - prefixLength + 1))
        let endIndex = text.index(text.startIndex, offsetBy: position + 1)
        let prefix = String(text[startIndex..<endIndex]).lowercased()
        
        for abbr in abbreviations {
            if prefix.hasSuffix(abbr) {
                return true
            }
        }
        return false
    }
    
    /// Find which sentence contains the given character offset
    static func sentenceIndex(at charOffset: Int, in sentences: [SentenceItem]) -> Int {
        for (i, sentence) in sentences.enumerated() {
            if charOffset >= sentence.charOffset && charOffset < sentence.charEnd {
                return i
            }
        }
        return 0
    }
}
