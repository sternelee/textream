import SwiftUI

struct IOSReaderView: View {
    @Bindable var model: IOSTeleprompterModel
    private let tickTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 16) {
                    topBar
                    teleprompterGrid
                    statusCard
                    sliderCard
                    bottomControls
                }
                .padding(16)
                .background(Color.black.ignoresSafeArea())
                .foregroundStyle(.white)
                .toolbar(.hidden, for: .navigationBar)
                .onReceive(tickTimer) { _ in
                    model.tick(deltaSeconds: 0.05)
                }
                .onChange(of: model.currentWordIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .alert("Textream", isPresented: Binding(
                    get: { model.presentedErrorMessage != nil },
                    set: { if !$0 { model.dismissPresentedError() } }
                )) {
                    Button("OK") { model.dismissPresentedError() }
                } message: {
                    Text(model.presentedErrorMessage ?? "")
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                model.stopReading()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 4) {
                Text(model.currentDocumentDisplayName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text("Page \(model.document.currentPageIndex + 1)/\(model.document.pages.count) · \(model.session.mode.label)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Circle()
                .fill(model.session.isPaused ? .orange : .green)
                .frame(width: 10, height: 10)
        }
    }

    private var teleprompterGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(model.currentWords.enumerated()), id: \.offset) { index, word in
                    Button {
                        model.jumpToWord(index: index)
                    } label: {
                        Text(word)
                            .font(.system(size: model.readerFontSize, weight: index == model.currentWordIndex ? .bold : .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(wordBackground(for: index))
                            .foregroundStyle(wordForeground(for: index))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .id(index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                waveformView
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.session.isListening ? "Mic On" : "Mic Off")
                        .font(.subheadline.weight(.medium))
                    if let message = model.readerStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(statusDetailLine)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sliderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(model.progressRatio * 100))%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }

            Slider(
                value: Binding(
                    get: {
                        switch model.session.mode {
                        case .wordTracking:
                            return Double(model.currentWordIndex)
                        case .classic, .voiceActivated:
                            return model.session.wordProgress
                        }
                    },
                    set: { newValue in
                        switch model.session.mode {
                        case .wordTracking:
                            model.jumpToWord(index: Int(newValue))
                        case .classic, .voiceActivated:
                            model.setWordProgress(newValue)
                        }
                    }
                ),
                in: 0...Double(max(model.currentWords.count, 1))
            )
            .tint(.yellow)
        }
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            controlButton(systemName: "backward.fill", disabled: !model.document.hasPreviousPage) {
                model.goToPreviousPage()
            }

            controlButton(systemName: model.session.isPaused ? "play.fill" : "pause.fill") {
                model.togglePause()
            }

            controlButton(systemName: micIcon, disabled: model.session.mode == .classic) {
                model.toggleListening()
            }

            controlButton(systemName: "forward.fill", disabled: !model.document.hasNextPage) {
                model.goToNextPage()
            }
        }
    }

    private var micIcon: String {
        switch model.session.mode {
        case .classic:
            return "arrow.down"
        case .voiceActivated, .wordTracking:
            return model.session.isListening ? "mic.fill" : "mic.slash.fill"
        }
    }

    private var statusDetailLine: String {
        switch model.session.mode {
        case .classic, .voiceActivated:
            return "word \(model.currentWordIndex + 1)/\(max(model.currentWords.count, 1))"
        case .wordTracking:
            return "chars \(model.session.recognizedCharCount)/\(max(model.currentCollapsedText.count, 1))"
        }
    }

    private var waveformView: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(model.session.audioLevels.enumerated()), id: \.offset) { index, level in
                let color: Color = {
                    if model.session.mode == .voiceActivated && model.audioMonitor.isSpeaking {
                        return .yellow
                    }
                    if model.session.mode == .wordTracking && model.session.isListening {
                        return .blue
                    }
                    return model.session.isListening ? .green : .white.opacity(0.35)
                }()

                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(index % 2 == 0 ? 0.95 : 0.72))
                    .frame(width: 4, height: max(6, level * 32))
            }
        }
        .frame(width: 120, height: 36, alignment: .leading)
    }

    private func wordBackground(for index: Int) -> Color {
        if index < model.currentWordIndex {
            return .white.opacity(0.08)
        }
        if index == model.currentWordIndex {
            return .yellow.opacity(0.22)
        }
        return .clear
    }

    private func wordForeground(for index: Int) -> Color {
        if index < model.currentWordIndex {
            return .white.opacity(0.45)
        }
        if index == model.currentWordIndex {
            return .yellow
        }
        return .white
    }

    private func controlButton(systemName: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white.opacity(disabled ? 0.05 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .opacity(disabled ? 0.45 : 1)
    }
}

#Preview {
    IOSReaderView(model: IOSTeleprompterModel())
}
