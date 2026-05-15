//
//  RadarChartView.swift
//  Textream
//
//  5-dimension radar chart for practice session skills assessment.
//

import SwiftUI

struct RadarDimension: Identifiable {
    let id = UUID()
    let label: String
    let value: Double // 0-100
    let icon: String
}

struct RadarChartView: View {
    let dimensions: [RadarDimension]
    let size: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Skill Radar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            
            ZStack {
                // Grid rings
                ForEach(1...4, id: \.self) { i in
                    let radius = size / 2 * Double(i) / 4
                    PolygonShape(sides: dimensions.count, radius: radius)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                
                // Axis lines
                ForEach(0..<dimensions.count, id: \.self) { i in
                    let angle = Double(i) * 2 * .pi / Double(dimensions.count) - .pi / 2
                    let x = cos(angle) * size / 2
                    let y = sin(angle) * size / 2
                    Path { path in
                        path.move(to: CGPoint(x: size/2, y: size/2))
                        path.addLine(to: CGPoint(x: size/2 + x, y: size/2 + y))
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                
                // Data polygon
                DataPolygon(dimensions: dimensions, radius: size/2)
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(
                        DataPolygon(dimensions: dimensions, radius: size/2)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                
                // Labels
                ForEach(0..<dimensions.count, id: \.self) { i in
                    let angle = Double(i) * 2 * .pi / Double(dimensions.count) - .pi / 2
                    let labelRadius = size / 2 + 24
                    let x = cos(angle) * labelRadius
                    let y = sin(angle) * labelRadius
                    
                    VStack(spacing: 2) {
                        Image(systemName: dimensions[i].icon)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(dimensions[i].label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(Int(dimensions[i].value))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(dimensions[i].value))
                    }
                    .position(x: size/2 + x, y: size/2 + y)
                }
            }
            .frame(width: size, height: size)
        }
    }
    
    private func scoreColor(_ value: Double) -> Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Shapes

struct PolygonShape: Shape {
    let sides: Int
    let radius: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<sides {
            let angle = Double(i) * 2 * .pi / Double(sides) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct DataPolygon: Shape {
    let dimensions: [RadarDimension]
    let radius: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<dimensions.count {
            let angle = Double(i) * 2 * .pi / Double(dimensions.count) - .pi / 2
            let r = radius * dimensions[i].value / 100
            let point = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
