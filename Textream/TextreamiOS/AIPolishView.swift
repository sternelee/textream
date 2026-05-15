//
//  AIPolishView.swift
//  TextreamiOS
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
        NavigationStack {
            Group {
                if showResult {
                    resultView
                } else {
                    actionGrid
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("AI Polish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Polish Error", isPresented: $showError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private var actionGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PolishAction.allCases, id: \.rawValue) { action in
                        Button {
                            performPolish(action: action)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                                Text(action.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isPolishing)
                    }
                }

                if isPolishing {
                    ProgressView("Polishing…")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(resultText)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(16)

            HStack(spacing: 12) {
                Button {
                    showResult = false
                    resultText = ""
                } label: {
                    Label("Back", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)

                Button {
                    onApply(resultText)
                    dismiss()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
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
