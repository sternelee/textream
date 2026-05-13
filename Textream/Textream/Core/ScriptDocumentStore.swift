import Foundation

enum ScriptDocumentStoreError: LocalizedError {
    case emptyDocument
    case unreadableData

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "The script document does not contain any pages."
        case .unreadableData:
            return "The script document could not be decoded."
        }
    }
}

/// Cross-platform encoder/decoder for `.textream` files.
/// Supports both the future structured format and the current legacy `[String]` page array format.
enum ScriptDocumentStore {
    static func load(from data: Data, fallbackTitle: String = "Untitled") throws -> ScriptDocument {
        let decoder = JSONDecoder()

        if let document = try? decoder.decode(ScriptDocument.self, from: data) {
            guard !document.pages.isEmpty else {
                throw ScriptDocumentStoreError.emptyDocument
            }
            return document
        }

        if let legacyPages = try? decoder.decode([String].self, from: data) {
            guard !legacyPages.isEmpty else {
                throw ScriptDocumentStoreError.emptyDocument
            }
            return ScriptDocument(title: fallbackTitle, pages: legacyPages)
        }

        throw ScriptDocumentStoreError.unreadableData
    }

    static func load(from url: URL) throws -> ScriptDocument {
        let data = try Data(contentsOf: url)
        let title = url.deletingPathExtension().lastPathComponent
        return try load(from: data, fallbackTitle: title.isEmpty ? "Untitled" : title)
    }

    /// Writes the current legacy file shape for backward compatibility with the existing macOS app.
    static func encodeLegacyPages(_ document: ScriptDocument) throws -> Data {
        let pages = document.pages.isEmpty ? [""] : document.pages
        return try JSONEncoder().encode(pages)
    }

    /// Writes a richer structured document shape for future iOS/macOS shared use.
    static func encodeStructuredDocument(_ document: ScriptDocument) throws -> Data {
        try JSONEncoder().encode(document)
    }

    static func saveLegacyPages(_ document: ScriptDocument, to url: URL) throws {
        let data = try encodeLegacyPages(document)
        try data.write(to: url, options: .atomic)
    }

    static func saveStructuredDocument(_ document: ScriptDocument, to url: URL) throws {
        let data = try encodeStructuredDocument(document)
        try data.write(to: url, options: .atomic)
    }
}
