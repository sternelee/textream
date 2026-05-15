//
//  MockQAView.swift
//  Textream
//
//  AI-generated mock Q&A questions for post-speech rehearsal.
//

import SwiftUI

struct MockQAView: View {
    let scriptText: String
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [String] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedQuestion: String?
    @State private var userAnswer = ""
    @State private var aiFeedback: String?
    @State private var isEvaluating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mock Q&A")
                        .font(.system(size: 15, weight: .bold))
                    Text("Practice answering audience questions")
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

            if let feedback = aiFeedback {
                feedbackView(feedback: feedback)
            } else if let selected = selectedQuestion {
                answerView(question: selected)
            } else if questions.isEmpty {
                emptyState
            } else {
                questionList
            }
        }
        .frame(width: 480, height: 520)
        .background(.ultraThinMaterial)
        .onAppear {
            if questions.isEmpty {
                generateQuestions()
            }
        }
        .alert("Generation Error", isPresented: $showError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Empty / Loading State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
                Text("AI is thinking of questions…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("No questions yet")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Button {
                    generateQuestions()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Generate Questions")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Question List

    private var questionList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 8) {
                ForEach(Array(questions.enumerated()), id: \.offset) { i, question in
                    Button {
                        selectedQuestion = question
                        userAnswer = ""
                        aiFeedback = nil
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())

                            Text(question)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    generateQuestions()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Regenerate")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    // MARK: - Answer View

    private func answerView(question: String) -> some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Question
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Question")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .textCase(.uppercase)
                        Text(question)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.06))
                    )

                    // Answer input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Answer")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        TextEditor(text: $userAnswer)
                            .font(.system(size: 13))
                            .frame(minHeight: 100, maxHeight: 180)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    selectedQuestion = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    evaluateAnswer(question: question)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Get Feedback")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEvaluating)
            }
            .padding(12)
        }
    }

    // MARK: - Feedback View

    private func feedbackView(feedback: String) -> some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Feedback")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(feedback)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    aiFeedback = nil
                    userAnswer = ""
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("Try Again")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    aiFeedback = nil
                    selectedQuestion = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                        Text("Next Question")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(12)
        }
    }

    // MARK: - Actions

    private func generateQuestions() {
        guard AIScriptService.shared.hasAPIKey else {
            errorMessage = "OpenAI API Key is not configured. Add it in Settings → AI."
            showError = true
            return
        }

        isGenerating = true
        questions = []
        AIScriptService.shared.generateQuestions(
            scriptText: scriptText,
            count: 5
        ) { result in
            isGenerating = false
            switch result {
            case .success(let qs):
                questions = qs
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func evaluateAnswer(question: String) {
        guard AIScriptService.shared.hasAPIKey else {
            errorMessage = "OpenAI API Key is not configured. Add it in Settings → AI."
            showError = true
            return
        }

        isEvaluating = true
        let prompt = """
Question: \(question)

User's Answer:
---
\(userAnswer)
---

Evaluate the answer. Be constructive:
1. What was strong about the answer?
2. What could be improved?
3. Suggest a better way to answer this question.
Keep it brief (3-5 sentences).
"""
        AIScriptService.shared.polish(
            text: "",
            instruction: prompt
        ) { result in
            isEvaluating = false
            switch result {
            case .success(let feedback):
                aiFeedback = feedback
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
