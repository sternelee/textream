//
//  AIPolishView.swift
//  Textream
//
//  AI polish actions for selected text.
//

import SwiftUI

enum PolishAction: String, CaseIterable {
    case shorter = "Shorter"
    case casual = "More Casual"
    case formal = "More Formal"
    case humorous = "Add Humor"
    case punchy = "More Punchy"
    case removeFillers = "Remove Fillers"
    
    var icon: String {
        switch self {
        case .shorter:      return "arrow.down.forward"
        case .casual:       return "bubble.left"
        case .formal:       return "briefcase"
        case .humorous:     return "face.smiling"
        case .punchy:       return "bolt.fill"
        case .removeFillers: return "scissors"
        }
    }
    
    var instruction: String {
        switch self {
        case .shorter:      return "Make this shorter by 30% while keeping all key points."
        case .casual:       return "Rewrite this to be more casual and conversational."
        case .formal:       return "Rewrite this to be more formal and professional."
        case .humorous:     return "Add a touch of humor while keeping the message clear."
        case .punchy:       return "Make this more punchy and impactful. Use shorter sentences."
        case .removeFillers: return "Remove filler words and make every word count."
        }
    }
}

struct AIPolishView: View {
    let selectedText: String
    let onApply: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isPolishing = false
    @State private var resultText = ""
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Polish")
                        .font(.system(size: 15, weight: .bold))
                    Text("Select a style to rewrite the selected text")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if showResult {
                resultView
            } else {
                actionGrid
            }
        }
        .frame(width: 380, height: showResult ? 480 : 320)
        .background(.ultraThinMaterial)
        .alert("Polish Error", isPresented: $showError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var actionGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Selected text preview
                Text(selectedText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(PolishAction.allCases, id: \.rawValue) { action in
                        Button {
                            performPolish(action: action)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                                Text(action.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isPolishing)
                    }
                }
            }
            .padding(16)
        }
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(resultText)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 10) {
                Button {
                    showResult = false
                    resultText = ""
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    onApply(resultText)
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                        Text("Apply")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func performPolish(action: PolishAction) {
        guard AIScriptService.shared.hasAPIKey else {
            errorMessage = "OpenAI API Key is not configured. Add it in Settings → AI."
            showError = true
            return
        }

        isPolishing = true
        AIScriptService.shared.polish(
            text: selectedText,
            instruction: action.instruction
        ) { result in
            isPolishing = false
            switch result {
            case .success(let text):
                resultText = text
                showResult = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
