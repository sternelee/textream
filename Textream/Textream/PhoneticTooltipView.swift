//
//  PhoneticTooltipView.swift
//  Textream
//
//  Floating tooltip showing phonetic hint for a difficult word.
//

import SwiftUI

struct PhoneticTooltipView: View {
    let result: PhoneticResult
    let onDismiss: () -> Void
    
    @State private var appeared = false
    
    private var hasAnyContent: Bool {
        !result.phonetic.isEmpty || !result.phoneticUK.isEmpty || !result.translation.isEmpty || !result.pronunciation.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with word
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(result.word)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.primary.opacity(0.1))
            
            if hasAnyContent {
                // IPA — show US and UK variants
                if !result.phonetic.isEmpty || !result.phoneticUK.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        if !result.phonetic.isEmpty {
                            HStack(spacing: 4) {
                                Text("US")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(result.phonetic)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                        if !result.phoneticUK.isEmpty && result.phoneticUK != result.phonetic {
                            HStack(spacing: 4) {
                                Text("UK")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                Text(result.phoneticUK)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                
                // Translation
                if !result.translation.isEmpty {
                    HStack(spacing: 4) {
                        Text(NotchSettings.shared.nativeLanguage.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(result.translation)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                    }
                }
                
                // Pronunciation guide
                if !result.pronunciation.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text("💡")
                            .font(.system(size: 11))
                        Text(result.pronunciation)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineLimit(3)
                    }
                }
            } else {
                // Loading state: data not yet available
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
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
            // Auto-dismiss after 8 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                onDismiss()
            }
        }
    }
}