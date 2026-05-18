//
//  PhoneticTooltipView.swift
//  Textream
//
//  Floating tooltip showing phonetic hint for a difficult word.
//

import SwiftUI
import AVFoundation

struct PhoneticTooltipView: View {
    let result: PhoneticResult
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var loadingTimedOut = false
    @State private var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    private func speak() {
        guard !result.word.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: result.word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42          // slightly slower than default for clarity
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSpeaking = false
        }
        synthesizer.speak(utterance)
    }

    private var hasAnyContent: Bool {
        !result.phonetic.isEmpty || !result.phoneticUK.isEmpty ||
        !result.translation.isEmpty || !result.pronunciation.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Button { speak() } label: {
                    Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSpeaking ? Color.accentColor.opacity(0.6) : Color.accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                }
                .buttonStyle(.plain)
                .help("Pronounce word")
                Text(result.word)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.primary.opacity(0.1))

            if hasAnyContent {
                // IPA
                if !result.phonetic.isEmpty || !result.phoneticUK.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        if !result.phonetic.isEmpty {
                            HStack(spacing: 4) {
                                Text("US")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(result.phonetic)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                        if !result.phoneticUK.isEmpty, result.phoneticUK != result.phonetic {
                            HStack(spacing: 4) {
                                Text("UK")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3).padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(result.phoneticUK)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                // Meaning / translation
                if !result.translation.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Meaning / Translation")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(result.translation)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                    }
                }

                // Guide / example
                if !result.pronunciation.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Guide / Example")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .top, spacing: 4) {
                            Text("💡")
                                .font(.system(size: 11))
                            Text(result.pronunciation)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary.opacity(0.8))
                                .lineLimit(3)
                        }
                    }
                }
            } else if loadingTimedOut {
                // No result after timeout — show message, never auto-dismiss
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("No built-in or online dictionary result")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                // Still loading
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Looking up…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.05))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appeared = true
            }
            // Loading timeout: switch to "No result" after 6 s
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if !hasAnyContent {
                    loadingTimedOut = true
                    // Do NOT auto-dismiss — user must close manually
                }
            }
        }
        // Auto-dismiss only when content is available
        .onChange(of: hasAnyContent) { _, gotContent in
            if gotContent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    onDismiss()
                }
            }
        }
    }
}
