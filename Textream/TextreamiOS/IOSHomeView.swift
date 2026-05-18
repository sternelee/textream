import SwiftUI

struct IOSHomeView: View {
    @Bindable var model: IOSTeleprompterModel
    /// Called when the user wants to switch to the Library tab (set by parent TabView)
    var switchToLibraryTab: (() -> Void)? = nil

    @State private var showingEditor = false
    @State private var showingAIGenerate = false
    @State private var showingDocumentPicker = false
    @State private var showingPractice = false
    @State private var showingPracticeHistory = false
    @State private var showingMockQA = false
    @State private var showingNewDocumentConfirmation = false
    @State private var showingLaunchRecovery = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        scriptCard(width: proxy.size.width)
                        modeSection
                        readButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .background(backgroundGradient.ignoresSafeArea())
            }
            .navigationTitle("Textream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    moreMenu
                }
            }
            // Sheets & covers
            .fullScreenCover(isPresented: $showingEditor) {
                IOSEditorView(model: model)
            }
            .fullScreenCover(isPresented: $model.isReaderPresented) {
                IOSReaderView(model: model)
            }
            .sheet(isPresented: $showingAIGenerate) {
                AIGenerateView(model: model)
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    model.importDocument(from: url)
                }
            }
            .sheet(isPresented: $showingPractice) {
                PracticeView(scriptText: model.document.pages.joined(separator: "\n\n"))
            }
            .sheet(isPresented: $showingPracticeHistory) {
                PracticeHistoryView()
            }
            .sheet(isPresented: $showingMockQA) {
                MockQAView(scriptText: model.document.pages.joined(separator: "\n\n"))
            }
            .sheet(isPresented: $model.isExportSheetPresented, onDismiss: {
                model.clearExportURL()
            }) {
                if let url = model.exportDocumentURL {
                    ActivityView(activityItems: [url])
                }
            }
            .alert("Unsaved Changes", isPresented: $showingNewDocumentConfirmation) {
                Button("Save & New") { model.saveDocument(); model.newDocument() }
                Button("Discard & New", role: .destructive) { model.newDocument() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Do you want to save the current script before creating a new one?")
            }
            .alert("Recovered Script", isPresented: Binding(
                get: { model.launchRecoveryMessage != nil },
                set: { if !$0 { model.dismissLaunchRecoveryMessage() } }
            )) {
                Button("OK") { model.dismissLaunchRecoveryMessage() }
            } message: {
                Text(model.launchRecoveryMessage ?? "")
            }
            .alert(model.presentedErrorMessage ?? "Error", isPresented: Binding(
                get: { model.presentedErrorMessage != nil },
                set: { if !$0 { model.dismissPresentedError() } }
            )) {
                Button("OK") { model.dismissPresentedError() }
            }
        }
    }

    // MARK: - Script Card

    private func scriptCard(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title + meta
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Untitled" : model.document.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.hasUnsavedChanges ? Color.orange : model.highlightColorPreset.tint)
                            .frame(width: 7, height: 7)
                        Text(model.currentDocumentStatusLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(model.hasUnsavedChanges ? Color.orange : model.highlightColorPreset.tint)
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(model.document.pages.count) pages")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text("\(model.totalWordCount) words")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(model.estimatedReadingTime)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Preview text
            if model.document.hasAnyContent {
                Text(currentPreviewText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.2), value: currentPreviewText)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.25))
                    Text("No content yet.\nTap Edit to write your script.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Edit button
            Button {
                showingEditor = true
            } label: {
                Label("Edit Script", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Mode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            modePicker

            Text(model.modeSupportDescription)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .animation(.easeInOut(duration: 0.15), value: model.selectedMode)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private var modePicker: some View {
        Picker("Mode", selection: $model.selectedMode) {
            Text(TeleprompterMode.wordTracking.label).tag(TeleprompterMode.wordTracking)
            Text(TeleprompterMode.classic.label).tag(TeleprompterMode.classic)
            Text(TeleprompterMode.voiceActivated.label).tag(TeleprompterMode.voiceActivated)
        }
        .pickerStyle(.segmented)
        .tint(.white)
    }

    // MARK: - Read Button

    private var readButton: some View {
        Button {
            model.startReading()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Start Reading")
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(model.document.hasAnyContent ? Color.black : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                model.document.hasAnyContent
                    ? AnyShapeStyle(model.highlightColorPreset.tint)
                    : AnyShapeStyle(Color.white.opacity(0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .disabled(!model.document.hasAnyContent)
        .animation(.easeInOut(duration: 0.2), value: model.document.hasAnyContent)
    }

    // MARK: - More Menu

    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Section("Script") {
                Button { confirmNewDocument() } label: {
                    Label("New Script", systemImage: "plus.square")
                }
                Button { showingDocumentPicker = true } label: {
                    Label("Import File", systemImage: "square.and.arrow.down")
                }
                Button { showingAIGenerate = true } label: {
                    Label("AI Script", systemImage: "wand.and.stars")
                }
                Button { switchToLibraryTab?() } label: {
                    Label("Library", systemImage: "books.vertical")
                }
            }

            if model.document.hasAnyContent {
                Section("Practice") {
                    Button { showingPractice = true } label: {
                        Label("Practice", systemImage: "mic")
                    }
                    Button { showingPracticeHistory = true } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    Button { showingMockQA = true } label: {
                        Label("Mock Q&A", systemImage: "bubble.left.and.bubble.right")
                    }
                }
                Section("Export") {
                    Button { model.saveDocument() } label: {
                        Label(model.hasUnsavedChanges ? "Save \u{2022}" : "Save", systemImage: "square.and.arrow.down")
                    }
                    Button { model.exportDocument() } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private var currentPreviewText: String {
        // Show current page preview text
        let current = model.document.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty { return String(current.prefix(200)) }
        // Fall back to first non-empty page
        let first = model.document.pages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        return String(first.prefix(200))
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.10),
                Color(red: 0.10, green: 0.11, blue: 0.17),
                Color(red: 0.04, green: 0.05, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func confirmNewDocument() {
        if model.hasUnsavedChanges {
            showingNewDocumentConfirmation = true
        } else {
            model.newDocument()
        }
    }
}

#Preview {
    IOSHomeView(model: IOSTeleprompterModel())
}
