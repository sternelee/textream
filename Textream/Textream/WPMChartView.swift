//
//  WPMChartView.swift
//  Textream
//
//  WPM trend chart for practice session reports.
//

import SwiftUI
import Charts

struct WPMChartView: View {
    let timestamps: [WordTimestamp]
    let duration: Double
    
    /// Calculate WPM at each word timestamp using a sliding window
    private var wpmData: [(time: Double, wpm: Double)] {
        guard timestamps.count > 1, duration > 0 else { return [] }
        let windowSize = 5 // words in sliding window
        var result: [(Double, Double)] = []
        
        for i in 0..<timestamps.count {
            let windowStart = max(0, i - windowSize / 2)
            let windowEnd = min(timestamps.count - 1, i + windowSize / 2)
            let wordCount = windowEnd - windowStart + 1
            let timeSpan = timestamps[windowEnd].endTime - timestamps[windowStart].startTime
            guard timeSpan > 0 else { continue }
            let wpm = Double(wordCount) / (timeSpan / 60.0)
            result.append((timestamps[i].startTime, min(wpm, 300))) // cap at 300
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed Trend")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            if wpmData.isEmpty {
                Text("No data available")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(wpmData, id: \.time) { point in
                    LineMark(
                        x: .value("Time", formatTime(point.time)),
                        y: .value("WPM", point.wpm)
                    )
                    .foregroundStyle(wpmColor(point.wpm))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", formatTime(point.time)),
                        y: .value("WPM", point.wpm)
                    )
                    .foregroundStyle(wpmColor(point.wpm).opacity(0.1))
                }
                .frame(height: 120)
                .chartYScale(domain: 0...300)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(String.self) {
                                Text(v)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Reference zone labels
            HStack(spacing: 12) {
                Label("Slow", systemImage: "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                Label("Ideal", systemImage: "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Label("Fast", systemImage: "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private func wpmColor(_ wpm: Double) -> Color {
        switch wpm {
        case 0..<100: return .blue
        case 100..<120: return .green
        case 120..<160: return .yellow
        case 160..<200: return .orange
        default: return .red
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
