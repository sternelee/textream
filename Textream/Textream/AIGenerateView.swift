//
//  AIGenerateView.swift
//  Textream
//
//  AI script generation interface.
//

import SwiftUI

struct AIGenerateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = TextreamService.shared
    @State private var selectedScenario: AIScenario = .keynoteSpeech
    @State private var userPrompt = ""
    @State private var generatedText = ""
    @State private var isGenerating = false
    @State private var showNoKeyAlert = false
    @State private var generationError: String?
    @State private var showError = false

    /// If true, appends to existing text instead of replacing
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Script Generator")
                        .font(.system(size: 15, weight: .bold))
                    Text("Select a scenario and describe your needs")
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
                .disabled(isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Scenario selection
                    Text("Scenario")
                        .font(.system(size: 13, weight: .medium))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(AIScenario.allCases) { scenario in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedScenario = scenario
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: scenario.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(selectedScenario == scenario ? Color.accentColor : .secondary)
                                    Text(scenario.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(selectedScenario == scenario ? Color.accentColor : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedScenario == scenario ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(selectedScenario == scenario ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Description
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(selectedScenario.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.04))
                    )

                    // User prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Details")
                            .font(.system(size: 13, weight: .medium))
                        TextEditor(text: $userPrompt)
                            .font(.system(size: 13))
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    if generatedText.isEmpty && !isGenerating {
                        Text(selectedScenario.placeholderText)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }

                    // Generated result
                    if !generatedText.isEmpty || isGenerating {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Generated Script")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                if isGenerating {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.7)
                                        Text("Generating…")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            ScrollView(.vertical, showsIndicators: true) {
                                Text(generatedText.isEmpty ? " " : generatedText)
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(minHeight: 120, maxHeight: 240)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Bottom actions
            HStack(spacing: 10) {
                if !generatedText.isEmpty && !isGenerating {
                    Button {
                        // Append to current page
                        let pageIndex = service.currentPageIndex
                        guard pageIndex < service.pages.count else { return }
                        let separator = service.pages[pageIndex].isEmpty ? "" : "\n\n"
                        service.pages[pageIndex] += separator + generatedText
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.append")
                                .font(.system(size: 11))
                            Text("Append")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        // Replace current page
                        let pageIndex = service.currentPageIndex
                        guard pageIndex < service.pages.count else { return }
                        service.pages[pageIndex] = generatedText
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11))
                            Text("Replace")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        // New page
                        service.pages.append(generatedText)
                        service.currentPageIndex = service.pages.count - 1
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 11))
                            Text("New Page")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                if isGenerating {
                Button {
                    AIScriptService.shared.stop()
                    isGenerating = false
                } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 11))
                            Text("Stop")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if !generatedText.isEmpty {
                    Button {
                        // Continue generating
                        continueGeneration()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 11))
                            Text("Continue")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        generatedText = ""
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Regenerate")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        startGeneration()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11))
                            Text("Generate")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || AIScriptService.shared.isGenerating)
                }
            }
            .padding(12)
        }
        .frame(width: 520, height: 580)
        .background(.ultraThinMaterial)
        .alert("API Key Required", isPresented: $showNoKeyAlert) {
            Button("Open Settings") {
                dismiss()
                NotificationCenter.default.post(name: .openSettings, object: nil)
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

    private func startGeneration() {
        guard AIScriptService.shared.hasAPIKey else {
            showNoKeyAlert = true
            return
        }

        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        generatedText = ""
        isGenerating = true

        // Save context for auto-generate continuity
        NotchSettings.shared.lastAIScenario = selectedScenario
        NotchSettings.shared.lastAIContext = prompt

        AIScriptService.shared.generate(
            scenario: selectedScenario,
            userPrompt: prompt,
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

        // Keep auto-generation continuity aligned with the current continuation context.
        NotchSettings.shared.lastAIScenario = selectedScenario
        NotchSettings.shared.lastAIContext = prompt

        let baseText = generatedText
        AIScriptService.shared.continueFrom(
            existingText: baseText,
            scenario: selectedScenario,
            userPrompt: prompt,
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
    AIGenerateView()
}
