//
//  DifficultyTracker.swift
//  TextreamiOS
//
//  Tracks sentences marked as difficult for focused practice.
//

import Foundation
import SwiftUI

struct DifficultSentence: Identifiable, Codable {
    let id: UUID
    let scriptHash: String
    let sentenceText: String
    let sentenceIndex: Int
    let markedAt: Date
    var practiceCount: Int
    var lastScore: Int
}

@Observable
class DifficultyTracker {
    static let shared = DifficultyTracker()

    var difficultSentences: [DifficultSentence] = []

    private var storageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("difficult_sentences.json")
    }

    private init() {
        load()
    }

    func markDifficult(scriptText: String, sentenceIndex: Int, sentenceText: String) {
        let hash = String(scriptText.hashValue)
        difficultSentences.removeAll { $0.scriptHash == hash && $0.sentenceIndex == sentenceIndex }

        let entry = DifficultSentence(
            id: UUID(),
            scriptHash: hash,
            sentenceText: sentenceText,
            sentenceIndex: sentenceIndex,
            markedAt: Date(),
            practiceCount: 0,
            lastScore: 0
        )
        difficultSentences.insert(entry, at: 0)
        save()
    }

    func unmarkDifficult(scriptText: String, sentenceIndex: Int) {
        let hash = String(scriptText.hashValue)
        difficultSentences.removeAll { $0.scriptHash == hash && $0.sentenceIndex == sentenceIndex }
        save()
    }

    func updatePractice(scriptText: String, sentenceIndex: Int, score: Int) {
        let hash = String(scriptText.hashValue)
        if let index = difficultSentences.firstIndex(where: { $0.scriptHash == hash && $0.sentenceIndex == sentenceIndex }) {
            difficultSentences[index].practiceCount += 1
            difficultSentences[index].lastScore = score
            save()
        }
    }

    func isDifficult(scriptText: String, sentenceIndex: Int) -> Bool {
        let hash = String(scriptText.hashValue)
        return difficultSentences.contains { $0.scriptHash == hash && $0.sentenceIndex == sentenceIndex }
    }

    func sentencesForScript(_ scriptText: String) -> [DifficultSentence] {
        let hash = String(scriptText.hashValue)
        return difficultSentences.filter { $0.scriptHash == hash }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(difficultSentences)
            try data.write(to: storageURL)
        } catch {
            print("Save difficult sentences failed: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            difficultSentences = try JSONDecoder().decode([DifficultSentence].self, from: data)
        } catch {
            difficultSentences = []
        }
    }
}
