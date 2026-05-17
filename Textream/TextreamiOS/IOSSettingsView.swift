import SwiftUI
import AVFoundation

struct IOSSettingsView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss
    @State private var isTestingMic = false
    @State private var micTestLevel: Double = 0
    @State private var micTestTimer: Timer?
    @State private var micRecorder: AVAudioRecorder?
    @State private var isFetchingModels = false
    @State private var fetchedModels: [String] = []
    @State private var aiConfigMessage: String? = nil
    @State private var settingsImportMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Default reading mode") {
                    Picker("Mode", selection: $model.selectedMode) {
                        ForEach(TeleprompterMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Text("The mode you pick here becomes the default the next time you open Textream.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Reader appearance") {
                    Picker("Font family", selection: $model.readerFontFamily) {
                        ForEach(IOSReaderFontFamily.allCases) { family in
                            Text(family.label).tag(family)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font size")
                            Spacer()
                            Text("\(Int(model.readerFontSize)) pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $model.readerFontSize, in: IOSReaderFontSizing.minimum...IOSReaderFontSizing.maximum, step: 1)
                            .tint(model.highlightColorPreset.tint)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Line spacing")
                            Spacer()
                            Text(String(format: "%.1fx", model.readerLineSpacing))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $model.readerLineSpacing, in: 0.8...2.5, step: 0.1)
                            .tint(model.highlightColorPreset.tint)
                    }

                    Picker("Highlight color", selection: $model.highlightColorPreset) {
                        ForEach(IOSHighlightColorPreset.allCases) { preset in
                            Label {
                                Text(preset.label)
                            } icon: {
                                Circle()
                                    .fill(preset.tint)
                                    .frame(width: 14, height: 14)
                            }
                            .tag(preset)
                        }
                    }

                    Toggle("Mirror mode", isOn: $model.mirrorModeEnabled)
                    Toggle("Force dark mode", isOn: $model.forceDarkMode)

                    previewCard
                }

                Section("Scrolling and speech") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Classic speed")
                            Spacer()
                            Text(String(format: "%.1f words/s", model.scrollSpeedWordsPerSecond))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $model.scrollSpeedWordsPerSecond, in: 0.5...6.0, step: 0.5)
                            .tint(model.highlightColorPreset.tint)
                    }

                    Picker("Speech locale", selection: $model.speechLocale) {
                        ForEach(IOSSpeechLocaleOption.allCases) { locale in
                            Text(locale.label).tag(locale)
                        }
                    }

                    Text("Voice-Activated uses live microphone levels. Word Tracking uses the speech locale selected here when starting recognition.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Microphone test") {
                    if isTestingMic {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Audio level")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(String(format: "%.3f", micTestLevel))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(micTestLevel > 0.07 ? model.highlightColorPreset.tint : .secondary)
                                        .frame(width: max(4, CGFloat(micTestLevel) * geo.size.width))
                                }
                            }
                            .frame(height: 12)
                            Text(micTestLevel > 0.07 ? "Speaking detected" : (micTestLevel > 0.015 ? "Ambient noise" : "Quiet"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)

                        Button("Stop test") {
                            stopMicTest()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button("Test microphone") {
                            startMicTest()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Text("Tap to briefly listen through the microphone and verify audio levels respond to your voice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Reading behavior") {
                    Toggle("Keep screen awake", isOn: $model.keepScreenAwakeWhileReading)
                    Toggle("Haptic feedback", isOn: $model.hapticEnabled)
                    Text("Prevent the device from auto-locking while reading.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Phonetic Lookup") {
                    Toggle("Enable lookup", isOn: $model.phoneticTooltipEnabled)
                    Picker("Phonetic source", selection: $model.phoneticSource) {
                        ForEach(PhoneticSource.allCases) { source in
                            Label(source.label, systemImage: source.icon).tag(source)
                        }
                    }
                    Picker("Native language", selection: $model.nativeLanguage) {
                        Text("中文").tag("zh")
                        Text("日本語").tag("ja")
                        Text("Español").tag("es")
                        Text("Français").tag("fr")
                        Text("Deutsch").tag("de")
                        Text("한국어").tag("ko")
                        Text("Italiano").tag("it")
                        Text("Português").tag("pt")
                        Text("Русский").tag("ru")
                    }
                    Text("Long-press any word in Reader to see phonetic transcription and translation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        exportSettingsToClipboard()
                    } label: {
                        Label("Copy Settings JSON", systemImage: "doc.on.doc")
                    }
                    Button {
                        importSettingsFromClipboard()
                    } label: {
                        Label("Paste Settings JSON", systemImage: "doc.on.clipboard")
                    }
                    if let message = settingsImportMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.hasPrefix("Imported") ? model.highlightColorPreset.tint : .orange)
                    }
                } header: {
                    Text("Import / Export")
                } footer: {
                    Text("Copy your current reader settings as JSON to share between devices, or paste a previously exported settings JSON.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    SecureField("API Key (sk-...)", text: Binding(
                        get: { AIScriptService.shared.openAIAPIKey },
                        set: { AIScriptService.shared.openAIAPIKey = $0 }
                    ))
                    .font(.body.monospaced())
                    .textContentType(.password)

                    TextField("Base URL", text: Binding(
                        get: { AIScriptService.shared.openAIBaseURL },
                        set: { AIScriptService.shared.openAIBaseURL = $0 }
                    ))
                    .font(.body)
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                    Picker("Model", selection: Binding(
                        get: { AIScriptService.shared.openAIModel },
                        set: { AIScriptService.shared.openAIModel = $0 }
                    )) {
                        ForEach(fetchedModels.isEmpty ? AIScriptService.shared.availableModels : fetchedModels, id: \.self) { modelName in
                            Text(modelName).tag(modelName)
                        }
                    }

                    if let message = aiConfigMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(model.highlightColorPreset.tint)
                    }

                    Button {
                        fetchModels()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(isFetchingModels ? "Fetching…" : "Refresh Models")
                        }
                    }
                    .disabled(isFetchingModels || AIScriptService.shared.openAIAPIKey.isEmpty)
                } header: {
                    Text("AI Configuration")
                } footer: {
                    Text("Add your OpenAI API key to enable AI script generation. Your key is stored locally on this device. Compatible with OpenAI API and any OpenAI-compatible endpoint.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Current build") {
                    Label("Local draft state is restored when the app returns.", systemImage: "square.and.arrow.down.on.square")
                    Label("Reader pauses microphone-based modes when the app moves to the background.", systemImage: "pause.circle")
                    Label("Built-in test scripts match the device checklist so you can validate flows faster.", systemImage: "checkmark.bubble")
                    HStack {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(appVersionString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Help & Tips") {
                    Label("Tap any word in Reader to jump to it.", systemImage: "cursorarrow.click")
                    Label("Double-tap the reading area to pause or resume.", systemImage: "hand.tap")
                    Label("Shake your device in Reader to pause or resume.", systemImage: "iphone.radiowaves.left.and.right")
                    Label("Swipe left or right in Reader to change pages.", systemImage: "arrow.left.arrow.right")
                    Label("Pinch to zoom in Reader to adjust font size.", systemImage: "arrow.up.left.and.arrow.down.right")
                    Label("Use keyboard shortcuts: Space = Pause, ←/→ = Pages, Home/End = Jump.", systemImage: "keyboard")
                }

                Section {
                    Button(role: .destructive) {
                        model.resetReaderSettings()
                    } label: {
                        Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Reset font, size, highlight color, scroll speed, speech locale, and reading mode to factory defaults.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func startMicTest() {
        isTestingMic = true
        micTestLevel = 0

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            isTestingMic = false
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("micTest.caf")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            micRecorder = recorder
            micTestTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                recorder.updateMeters()
                let db = recorder.averagePower(forChannel: 0)
                let level = Double(pow(10, db / 20))
                micTestLevel = min(max(level, 0), 1)
            }
        } catch {
            isTestingMic = false
        }
    }

    private func stopMicTest() {
        micTestTimer?.invalidate()
        micTestTimer = nil
        micRecorder?.stop()
        micRecorder = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {}
        isTestingMic = false
        micTestLevel = 0
    }

    private func exportSettingsToClipboard() {
        let settings = IOSPersistedReaderSettings(
            selectedMode: model.selectedMode,
            fontSize: model.readerFontSize,
            fontFamily: model.readerFontFamily,
            highlightColor: model.highlightColorPreset,
            scrollSpeedWordsPerSecond: model.scrollSpeedWordsPerSecond,
            speechLocale: model.speechLocale,
            lineSpacing: model.readerLineSpacing,
            keepScreenAwake: model.keepScreenAwakeWhileReading,
            hapticEnabled: model.hapticEnabled,
            mirrorModeEnabled: model.mirrorModeEnabled,
            forceDarkMode: model.forceDarkMode,
            phoneticTooltipEnabled: model.phoneticTooltipEnabled,
            nativeLanguage: model.nativeLanguage,
            phoneticSource: model.phoneticSource
        )
        do {
            let data = try JSONEncoder().encode(settings)
            let json = String(data: data, encoding: .utf8) ?? "{}"
            UIPasteboard.general.string = json
            settingsImportMessage = "Settings copied to clipboard."
        } catch {
            settingsImportMessage = "Failed to export settings."
        }
    }

    private func importSettingsFromClipboard() {
        guard let json = UIPasteboard.general.string, !json.isEmpty else {
            settingsImportMessage = "Clipboard is empty."
            return
        }
        guard let data = json.data(using: .utf8) else {
            settingsImportMessage = "Invalid clipboard content."
            return
        }
        do {
            let settings = try JSONDecoder().decode(IOSPersistedReaderSettings.self, from: data)
            model.selectedMode = settings.selectedMode
            model.readerFontSize = settings.fontSize
            model.readerFontFamily = settings.fontFamily
            model.highlightColorPreset = settings.highlightColor
            model.scrollSpeedWordsPerSecond = settings.scrollSpeedWordsPerSecond
            model.speechLocale = settings.speechLocale
            model.readerLineSpacing = settings.lineSpacing
            model.keepScreenAwakeWhileReading = settings.keepScreenAwake
            model.hapticEnabled = settings.hapticEnabled
            model.mirrorModeEnabled = settings.mirrorModeEnabled
            model.forceDarkMode = settings.forceDarkMode
            model.phoneticTooltipEnabled = settings.phoneticTooltipEnabled
            model.nativeLanguage = settings.nativeLanguage
            model.phoneticSource = settings.phoneticSource
            settingsImportMessage = "Imported settings successfully."
        } catch {
            settingsImportMessage = "Invalid settings JSON: \(error.localizedDescription)"
        }
    }

    private func fetchModels() {
        isFetchingModels = true
        aiConfigMessage = nil
        AIScriptService.shared.fetchModels { result in
            isFetchingModels = false
            switch result {
            case .success(let models):
                fetchedModels = models
                aiConfigMessage = "Fetched \(models.count) models."
            case .failure(let error):
                aiConfigMessage = error.localizedDescription
            }
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reader preview")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("The")
                    .font(.system(size: model.readerFontSize, weight: .semibold, design: model.readerFontFamily.fontDesign))
                    .foregroundStyle(.secondary)
                Text("quick")
                    .font(.system(size: model.readerFontSize, weight: .semibold, design: model.readerFontFamily.fontDesign))
                    .foregroundStyle(.secondary)
                Text("brown")
                    .font(.system(size: model.readerFontSize, weight: .bold, design: model.readerFontFamily.fontDesign))
                    .foregroundStyle(model.highlightColorPreset.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(model.highlightColorPreset.softBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("fox")
                    .font(.system(size: model.readerFontSize, weight: .semibold, design: model.readerFontFamily.fontDesign))
                    .foregroundStyle(.primary)
                Text("jumps")
                    .font(.system(size: model.readerFontSize, weight: .semibold, design: model.readerFontFamily.fontDesign))
                    .foregroundStyle(.primary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text("Your selected font, size, and highlight color will be used in Reader mode.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    IOSSettingsView(model: IOSTeleprompterModel())
}
