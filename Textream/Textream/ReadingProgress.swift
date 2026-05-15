//
//  ReadingProgress.swift
//  Textream
//
//  Resume reading from last position.
//

import Foundation

struct ReadingProgress: Codable {
    let fileURL: String?          // nil for unsaved documents
    let fileHash: String          // content hash for matching
    let pageIndex: Int
    let charOffset: Int           // recognizedCharCount in the page
    let timestamp: Date
    let wordSnippet: String       // last few words for display
    let pageCount: Int
}

final class ReadingProgressStore {
    static let shared = ReadingProgressStore()
    private let key = "textream.readingProgress"

    private init() {}

    func save(progress: ReadingProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> ReadingProgress? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReadingProgress.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Check if saved progress matches current document.
    func matchingProgress(fileURL: URL?, pages: [String]) -> ReadingProgress? {
        guard let saved = load() else { return nil }
        let currentHash = contentHash(pages: pages)
        if saved.fileHash == currentHash {
            return saved
        }
        // Fallback: if fileURL matches, also accept (file was saved since last read)
        if let url = fileURL, saved.fileURL == url.absoluteString {
            return saved
        }
        return nil
    }

    private func contentHash(pages: [String]) -> String {
        let content = pages.joined(separator: "\n---PAGE---\n")
        let data = Data(content.utf8)
        return data.base64EncodedString().prefix(16).description
    }
}
