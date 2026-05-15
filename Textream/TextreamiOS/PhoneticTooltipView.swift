//
//  PhoneticTooltipView.swift
//  TextreamiOS
//
//  Sheet-style phonetic lookup result.
//

import SwiftUI
import AVFoundation

struct PhoneticTooltipView: View {
    let word: String
    let nativeLanguage: String
    @State private var result: PhoneticResult?
    @State private var isLoading = true
    @State private var isSpeaking = false
    @Environment(\.dismiss) private var dismiss

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 10) {
                        Button { speak() } label: {
                            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundStyle(isSpeaking ? Color.accentColor : .primary)
                                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Text(word)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()
                    }

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Looking up…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else if let result = result {
                        if !result.phonetic.isEmpty || !result.phoneticUK.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Phonetic")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                if !result.phonetic.isEmpty {
                                    HStack(spacing: 6) {
                                        Text("US")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.red.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text(result.phonetic)
                                            .font(.system(size: 18, weight: .medium, design: .serif))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                                if !result.phoneticUK.isEmpty, result.phoneticUK != result.phonetic {
                                    HStack(spacing: 6) {
                                        Text("UK")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text(result.phoneticUK)
                                            .font(.system(size: 18, weight: .medium, design: .serif))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if !result.translation.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Translation")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Text(result.translation)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary)
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if !result.pronunciation.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pronunciation Guide")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                HStack(alignment: .top, spacing: 6) {
                                    Text("💡")
                                    Text(result.pronunciation)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.primary.opacity(0.85))
                                }
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("No result found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Word Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadPhonetic()
        }
    }

    private func loadPhonetic() async {
        isLoading = true
        result = nil
        result = await PhoneticTooltipService.shared.fetchHintAsync(for: word, targetLanguage: nativeLanguage)
        isLoading = false
    }

    private func speak() {
        guard !word.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSpeaking = false
        }
        synthesizer.speak(utterance)
    }
}

#Preview {
    PhoneticTooltipView(word: "entrepreneur", nativeLanguage: "zh")
}
