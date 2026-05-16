//
//  AIGenerateView.swift
//  Textream
//
//  AI script generation interface for iOS.
//

import SwiftUI

struct AIGenerateView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScenario: AIScenario = .keynoteSpeech
    @State private var userPrompt = ""
    @State private var generatedText = ""
    @State private var isGenerating = false
    @State private var showNoKeyAlert = false
    @State private var generationError: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scenarioSection
                    promptSection
                    resultSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.07, blue: 0.10),
                        Color(red: 0.10, green: 0.11, blue: 0.17),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .foregroundStyle(.white)
            .navigationTitle("AI Script Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        AIScriptService.shared.stop()
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
            }
            .alert("API Key Required", isPresented: $showNoKeyAlert) {
                Button("Open Settings") {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please configure your OpenAI API Key in Settings → AI first.")
            }
            .alert("Generation Error", isPresented: $showError) {
                Button("OK") { generationError = nil }
            } message: {
                Text(generationError ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Sections

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenario")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                ForEach(AIScenario.allCases) { scenario in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedScenario = scenario
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: scenario.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(selectedScenario == scenario ? model.highlightColorPreset.tint : .white.opacity(0.6))
                            Text(scenario.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(selectedScenario == scenario ? .white : .white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedScenario == scenario ? model.highlightColorPreset.softBackground : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(selectedScenario == scenario ? model.highlightColorPreset.tint.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text(selectedScenario.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(.white)

            TextEditor(text: $userPrompt)
                .font(.body)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if userPrompt.isEmpty && !isGenerating {
                Text(selectedScenario.placeholderText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !generatedText.isEmpty || isGenerating {
                HStack {
                    Text("Generated Script")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if isGenerating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                            Text("Generating…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                ScrollView(.vertical, showsIndicators: true) {
                    Text(generatedText.isEmpty ? " " : generatedText)
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(minHeight: 120, maxHeight: 280)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }

            actionButtons
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !generatedText.isEmpty && !isGenerating {
                HStack(spacing: 10) {
                    actionButton(title: "Append", icon: "text.append", style: .secondary) {
                        let separator = model.document.currentPageText.isEmpty ? "" : "\n\n"
                        let newText = model.document.currentPageText + separator + generatedText
                        model.updateCurrentPageText(String(newText.prefix(50000)))
                        model.documentStatusMessage = "Appended AI-generated text to current page."
                        dismiss()
                    }

                    actionButton(title: "Replace", icon: "doc.text", style: .primary) {
                        model.updateCurrentPageText(String(generatedText.prefix(50000)))
                        model.documentStatusMessage = "Replaced current page with AI-generated text."
                        dismiss()
                    }

                    actionButton(title: "New Page", icon: "doc.badge.plus", style: .secondary) {
                        model.document.addPage(after: model.document.currentPageIndex, text: String(generatedText.prefix(50000)))
                        model.documentStatusMessage = "Added AI-generated text as new page."
                        model.persistDraft()
                        dismiss()
                    }
                }

                HStack(spacing: 10) {
                    actionButton(title: "Regenerate", icon: "arrow.counterclockwise", style: .secondary) {
                        generatedText = ""
                        startGeneration()
                    }

                    actionButton(title: "Continue", icon: "arrow.right.circle", style: .primary) {
                        continueGeneration()
                    }
                }
            } else if isGenerating {
                Button {
                    AIScriptService.shared.stop()
                    isGenerating = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startGeneration()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(model.highlightColorPreset.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
        }
    }

    private func actionButton(title: String, icon: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(style == .primary ? Color.black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(style == .primary ? model.highlightColorPreset.tint : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private enum ActionButtonStyle {
        case primary
        case secondary
    }

    // MARK: - Generation Logic

    private func startGeneration() {
        guard AIScriptService.shared.hasAPIKey else {
            showNoKeyAlert = true
            return
        }

        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        generatedText = ""
        isGenerating = true

        UserDefaults.standard.set(selectedScenario.rawValue, forKey: "lastAIScenario")
        UserDefaults.standard.set(prompt, forKey: "lastAIContext")

        AIScriptService.shared.generate(
            scenario: selectedScenario,
            userPrompt: prompt,
            speechLocale: model.speechLocale.localeIdentifier,
            onUpdate: { text in
                generatedText = text
            },
            onComplete: { result in
                isGenerating = false
                switch result {
                case .success(let text):
                    generatedText = text
                case .failure(let error):
                    generationError = error.localizedDescription
                    showError = true
                }
            }
        )
    }

    private func continueGeneration() {
        guard AIScriptService.shared.hasAPIKey else {
            showNoKeyAlert = true
            return
        }

        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        isGenerating = true

        UserDefaults.standard.set(selectedScenario.rawValue, forKey: "lastAIScenario")
        UserDefaults.standard.set(prompt, forKey: "lastAIContext")

        let baseText = generatedText
        AIScriptService.shared.continueFrom(
            existingText: baseText,
            scenario: selectedScenario,
            userPrompt: prompt,
            speechLocale: model.speechLocale.localeIdentifier,
            onUpdate: { text in
                generatedText = baseText + text
            },
            onComplete: { result in
                isGenerating = false
                switch result {
                case .success(let text):
                    generatedText = baseText + text
                case .failure(let error):
                    generationError = error.localizedDescription
                    showError = true
                }
            }
        )
    }
}

#Preview {
    AIGenerateView(model: IOSTeleprompterModel())
}
