import Foundation

/// Shared text helpers for iOS/macOS teleprompter rendering.
enum TextSegmentation {
    nonisolated static func splitIntoWords(_ text: String) -> [String] {
        let tokens = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .map(String.init)

        var result: [String] = []
        for token in tokens {
            guard token.unicodeScalars.contains(where: isCJKScalar) else {
                result.append(token)
                continue
            }

            var buffer = ""
            for character in token {
                if character.unicodeScalars.first.map(isCJKScalar) == true {
                    if !buffer.isEmpty {
                        result.append(buffer)
                        buffer = ""
                    }
                    result.append(String(character))
                } else {
                    buffer.append(character)
                }
            }

            if !buffer.isEmpty {
                result.append(buffer)
            }
        }
        return result
    }

    nonisolated static func isAnnotationWord(_ word: String) -> Bool {
        if word.hasPrefix("[") && word.hasSuffix("]") {
            return true
        }
        let stripped = word.filter { $0.isLetter || $0.isNumber }
        return stripped.isEmpty
    }

    private nonisolated static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x4E00 && value <= 0x9FFF)
            || (value >= 0x3400 && value <= 0x4DBF)
            || (value >= 0x20000 && value <= 0x2A6DF)
            || (value >= 0xF900 && value <= 0xFAFF)
            || (value >= 0x3040 && value <= 0x309F)
            || (value >= 0x30A0 && value <= 0x30FF)
            || (value >= 0xAC00 && value <= 0xD7AF)
    }
}
