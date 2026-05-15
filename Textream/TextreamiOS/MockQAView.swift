//
//  MockQAView.swift
//  TextreamiOS
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
        NavigationStack {
            Group {
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
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Mock Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Generation Error", isPresented: $showError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .onAppear {
                if questions.isEmpty {
                    generateQuestions()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            if isGenerating {
                ProgressView()
                    .scaleEffect(1.2)
                Text("AI is thinking of questions…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("No questions yet")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Button {
                    generateQuestions()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                        Text("Generate Questions")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var questionList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(questions.enumerated()), id: \.offset) { i, question in
                    Button {
                        selectedQuestion = question
                        userAnswer = ""
                        aiFeedback = nil
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())

                            Text(question)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
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
                            .font(.system(size: 12))
                        Text("Regenerate")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private func answerView(question: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUESTION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(question)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.06))
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR ANSWER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $userAnswer)
                            .font(.system(size: 15))
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
            }

            HStack(spacing: 12) {
                Button {
                    selectedQuestion = nil
                } label: {
                    Label("Back", systemImage: "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    evaluateAnswer(question: question)
                } label: {
                    if isEvaluating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Get Feedback", systemImage: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEvaluating)
            }
            .padding(16)
        }
    }

    private func feedbackView(feedback: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI Feedback")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(feedback)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }

            HStack(spacing: 12) {
                Button {
                    aiFeedback = nil
                    userAnswer = ""
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    aiFeedback = nil
                    selectedQuestion = nil
                } label: {
                    Label("Next Question", systemImage: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

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
