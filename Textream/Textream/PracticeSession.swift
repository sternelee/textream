//
//  PracticeSession.swift
//  Textream
//
//  Practice session data model for speech rehearsal recording & analysis.
//

import Foundation

struct WordTimestamp: Codable {
    let word: String
    let startTime: Double // seconds from session start
    let endTime: Double
    let charOffset: Int
}

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let scriptText: String
    let recordingURL: URL?
    let duration: Double // seconds
    let wordTimestamps: [WordTimestamp]
    let recognizedText: String
    
    // Stats
    let averageWPM: Double
    let pauseCount: Int
    let totalPauseTime: Double
    let fillerWordCount: Int
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var score: Int {
        // Simple scoring: base 70, + for WPM in sweet spot (120-160), - for fillers
        var s = 70
        if averageWPM >= 120 && averageWPM <= 160 { s += 15 }
        else if averageWPM >= 100 && averageWPM <= 180 { s += 5 }
        s -= fillerWordCount * 2
        s -= max(0, pauseCount - 3) * 2
        return max(0, min(100, s))
    }
}
