import Foundation

struct SavedScriptDocument: Identifiable, Hashable {
    let url: URL
    let title: String
    let modifiedAt: Date

    var id: URL { url }
}

@Observable
final class IOSDocumentLibrary {
    var documents: [SavedScriptDocument] = []
    var errorMessage: String?

    private let fileManager = FileManager.default
    private let folderName = "TextreamDocuments"

    init() {
        refresh()
    }

    func refresh() {
        errorMessage = nil
        let directory = storageDirectory()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            documents = try urls
                .filter { $0.pathExtension.lowercased() == "textream" }
                .map { url in
                    let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                    return SavedScriptDocument(
                        url: url,
                        title: url.deletingPathExtension().lastPathComponent,
                        modifiedAt: values.contentModificationDate ?? .distantPast
                    )
                }
                .sorted { $0.modifiedAt > $1.modifiedAt }
        } catch {
            errorMessage = error.localizedDescription
            documents = []
        }
    }

    func load(_ item: SavedScriptDocument) throws -> ScriptDocument {
        try ScriptDocumentStore.load(from: item.url)
    }

    @discardableResult
    func save(document: ScriptDocument, preferredTitle: String, currentURL: URL? = nil) throws -> URL {
        let targetURL = try resolveSaveURL(preferredTitle: preferredTitle, currentURL: currentURL)
        try ScriptDocumentStore.saveLegacyPages(document, to: targetURL)
        refresh()
        return targetURL
    }

    func delete(_ item: SavedScriptDocument) throws {
        try fileManager.removeItem(at: item.url)
        refresh()
    }

    private func storageDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private func resolveSaveURL(preferredTitle: String, currentURL: URL?) throws -> URL {
        let directory = storageDirectory()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if let currentURL {
            return currentURL
        }

        let baseName = sanitizedFilename(from: preferredTitle.isEmpty ? "Untitled" : preferredTitle)
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("textream")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("textream")
            suffix += 1
        }
        return candidate
    }

    private func sanitizedFilename(from text: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = text.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
