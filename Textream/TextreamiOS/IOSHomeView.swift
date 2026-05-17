import SwiftUI

struct IOSHomeView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSettings = false
    @State private var showingLibrary = false
    @State private var showingDeletePageConfirmation = false
    @State private var showingDocumentPicker = false
    @State private var showingAIGenerate = false
    @State private var showingNewDocumentConfirmation = false
    @State private var showingFindReplace = false
    @State private var showAutoSaveIndicator = false
    @State private var autoSaveTimer: Timer?
    @State private var newTagText = ""
    @State private var showingAddTag = false
    @State private var showingPractice = false
    @State private var showingPracticeHistory = false
    @State private var showingPolish = false
    @State private var showingMockQA = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                ScrollView {
                    Group {
                        if prefersWideLayout(for: width) {
                            wideLayout(width: width)
                        } else {
                            compactLayout(width: width)
                        }
                    }
                    .frame(maxWidth: 1220)
                    .padding(.horizontal, horizontalPadding(for: width))
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .background(backgroundGradient.ignoresSafeArea())
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: model.lastAutoSavedAt) { _, _ in
                    showAutoSaveIndicator = true
                    autoSaveTimer?.invalidate()
                    autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                        withAnimation { showAutoSaveIndicator = false }
                    }
                }
            }
            .navigationTitle("Textream")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSettings) {
                IOSSettingsView(model: model)
            }
            .sheet(isPresented: $showingLibrary) {
                IOSDocumentLibraryView(model: model)
            }
            .fullScreenCover(isPresented: $model.isReaderPresented) {
                IOSReaderView(model: model)
            }
            .sheet(isPresented: $model.isExportSheetPresented, onDismiss: {
                model.clearExportURL()
            }) {
                if let url = model.exportDocumentURL {
                    ActivityView(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    model.importDocument(from: url)
                }
            }
            .sheet(isPresented: $showingAIGenerate) {
                AIGenerateView(model: model)
            }
            .sheet(isPresented: $showingPractice) {
                PracticeView(scriptText: model.document.pages.joined(separator: "\n\n"))
            }
            .sheet(isPresented: $showingPracticeHistory) {
                PracticeHistoryView()
            }
            .sheet(isPresented: $showingPolish) {
                AIPolishView(selectedText: model.document.currentPageText) { polished in
                    model.updateCurrentPageText(polished)
                }
            }
            .sheet(isPresented: $showingMockQA) {
                MockQAView(scriptText: model.document.pages.joined(separator: "\n\n"))
            }
            .sheet(isPresented: $showingFindReplace) {
                FindReplaceSheet(model: model)
            }
            .alert("Textream", isPresented: Binding(
                get: { model.presentedErrorMessage != nil },
                set: { if !$0 { model.dismissPresentedError() } }
            )) {
                Button("OK") { model.dismissPresentedError() }
            } message: {
                Text(model.presentedErrorMessage ?? "")
            }
            .confirmationDialog("Delete current page?", isPresented: $showingDeletePageConfirmation, titleVisibility: .visible) {
                Button("Delete Page", role: .destructive) {
                    model.removeCurrentPage()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes page \(model.document.currentPageIndex + 1). Textream will keep the remaining pages and move you to the nearest page.")
            }
            .confirmationDialog("You have unsaved changes", isPresented: $showingNewDocumentConfirmation, titleVisibility: .visible) {
                Button("Save & New", role: .none) {
                    model.saveDocument()
                    model.newDocument()
                }
                Button("Discard & New", role: .destructive) {
                    model.newDocument()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save your current script before starting a new one, or discard the changes.")
            }
        }
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

    private func compactLayout(width: CGFloat) -> some View {
        VStack(spacing: 18) {
            heroCard(compact: isCompactWidth(width))
            pageSection(width: width)
            editorCard(compact: isCompactWidth(width))
            modeCard(compact: isCompactWidth(width))
            sampleScriptsCard(compact: isCompactWidth(width))
        }
    }

    private func wideLayout(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 18) {
                heroCard(compact: false)
                pageSection(width: width * 0.48)
                sampleScriptsCard(compact: false)
            }
            .frame(maxWidth: 520)

            VStack(spacing: 18) {
                editorCard(compact: false)
                modeCard(compact: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func heroCard(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focused teleprompter for iPhone and iPad")
                            .font(compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Edit scripts, jump between pages, and read with classic, speech-aware, or word-tracking progression.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer(minLength: 0)

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                if let launchRecoveryMessage = model.launchRecoveryMessage {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(model.highlightColorPreset.tint)
                        Text(launchRecoveryMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer(minLength: 0)
                        Button {
                            model.dismissLaunchRecoveryMessage()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(model.highlightColorPreset.softBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Script title")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                    TextField("Untitled", text: $model.pageTitle)
                        .textFieldStyle(.plain)
                        .font(compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 8) {
                        Label(model.currentDocumentDisplayName, systemImage: "doc.text")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Label(model.currentDocumentStatusLabel, systemImage: model.hasUnsavedChanges ? "circle.fill" : "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(model.hasUnsavedChanges ? Color.orange : model.highlightColorPreset.tint)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        actionChip(title: "New", systemImage: "plus.square.on.square", action: confirmNewDocument)
                            .keyboardShortcut("n", modifiers: .command)
                        actionChip(title: "Open", systemImage: "folder", action: { showingLibrary = true })
                            .keyboardShortcut("o", modifiers: .command)
                        actionChip(title: "AI", systemImage: "wand.and.stars", highlighted: true, action: { showingAIGenerate = true })
                        if model.document.hasAnyContent {
                            actionChip(title: "Read", systemImage: "play.fill", highlighted: true, action: model.startReading)
                                .keyboardShortcut("r", modifiers: .command)
                            actionChip(title: "Practice", systemImage: "mic", action: { showingPractice = true })
                        }
                        actionChip(title: model.hasUnsavedChanges ? "Save*" : "Save", systemImage: "square.and.arrow.down", highlighted: model.hasUnsavedChanges, action: model.saveDocument)
                            .keyboardShortcut("s", modifiers: .command)
                    }
                }

                statRow(compact: compact)
                detailStatRow(compact: compact)

                recentDocumentsRow()

                if let status = model.documentStatusMessage {
                    Label(status, systemImage: model.presentedErrorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(model.presentedErrorMessage == nil ? .white.opacity(0.82) : Color.orange)
                }
            }
        }
    }

    private func statRow(compact: Bool) -> some View {
        LazyVGrid(columns: statColumns(compact: compact), spacing: 10) {
            statCapsule(title: "Pages", value: "\(model.document.pages.count)")
            statCapsule(title: "Words", value: "\(model.totalWordCount)")
            statCapsule(title: "Mode", value: model.selectedMode.label)
            statCapsule(title: "State", value: model.currentDocumentStatusLabel)
        }
    }

    private func detailStatRow(compact: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "character")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(model.totalCharCount) chars")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(model.estimatedReadingTime)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func recentDocumentsRow() -> some View {
        let recents = model.documentLibrary.documents
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(3)
        guard !recents.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Recent scripts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Button {
                        showingLibrary = true
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(model.highlightColorPreset.tint)
                    }
                    .buttonStyle(.plain)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(Array(recents), id: \.id) { item in
                        Button {
                            model.loadDocument(item)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(item.pageCount) pages · \(item.wordCount) words")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        )
    }

    private func pageSection(width: CGFloat) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pages")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Tap a page to edit it. Read pages are marked so you can keep your place.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button {
                        model.addPage()
                    } label: {
                        Label("Add Page", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.highlightColorPreset.tint)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: pageColumns(for: width), spacing: 12) {
                    ForEach(Array(model.document.pages.enumerated()), id: \.offset) { index, page in
                        Button {
                            model.jumpToPage(index)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Page \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 0)
                                    Image(systemName: model.document.readPages.contains(index) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(model.document.readPages.contains(index) ? model.highlightColorPreset.tint : .white.opacity(0.35))
                                }

                                Text(pagePreview(for: page))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                Text("\(TextSegmentation.splitIntoWords(page).count) words")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                            .padding(12)
                            .background(pageBackground(for: index))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(index == model.document.currentPageIndex ? model.highlightColorPreset.tint.opacity(0.7) : .white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func editorCard(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: compact ? 8 : 14) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Script Title", text: $model.document.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.words)
                        HStack(spacing: 6) {
                            Text("Page \(model.document.currentPageIndex + 1) · \(model.currentPageWordCount) words · \(model.currentPageCharCount) chars")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.65))
                            if showAutoSaveIndicator {
                                Text("Auto-saved")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(model.highlightColorPreset.tint)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    // Toolbar: compact icon-only buttons with overflow Menu
                    editorToolbar(compact: compact)
                }

                if !compact || !model.document.tags.isEmpty {
                    tagRow()
                }

                HStack(spacing: 10) {
                    compactPageButton(title: "Prev", systemImage: "chevron.left", disabled: !model.document.hasPreviousPage) {
                        model.goToPreviousPage()
                    }
                    compactPageButton(title: "Next", systemImage: "chevron.right", disabled: !model.document.hasNextPage) {
                        model.goToNextPage()
                    }
                    Text(model.document.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Current page is empty" : "Current page will be used when Reader starts")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Outline & Mini-map — skip on compact screens to reclaim vertical space
                if !compact, !model.document.currentPageText.isEmpty {
                    VStack(spacing: 10) {
                        ScriptOutlineView(
                            text: model.document.currentPageText,
                            currentCharOffset: 0
                        ) { offset in
                            // Jump to character offset in text editor
                            // Note: iOS TextEditor doesn't support programmatic selection,
                            // so we display the outline for visual reference
                        }
                        ScriptMiniMapView(
                            text: model.document.currentPageText,
                            currentCharOffset: 0
                        )
                    }
                }

                TextEditor(text: Binding(
                    get: { model.document.currentPageText },
                    set: { model.updateCurrentPageText($0) }
                ))
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.white)
                .frame(minHeight: compact ? 50 : 280)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Clear") {
                            model.updateCurrentPageText("")
                        }
                        .foregroundStyle(Color.red.opacity(0.8))
                        Button("Line Break") {
                            let current = model.document.currentPageText
                            model.updateCurrentPageText(current + "\n")
                        }
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.bold)
                    }
                }

                let targetWordCount = 500
                let progress = min(1.0, Double(model.currentPageWordCount) / Double(targetWordCount))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 3)
                        Rectangle()
                            .fill(model.highlightColorPreset.tint)
                            .frame(width: geo.size.width * CGFloat(progress), height: 3)
                    }
                }
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

                HStack(spacing: 12) {
                    Label("\(model.currentPageWordCount) words", systemImage: "textformat")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                    Label("\(model.currentPageCharCount) chars", systemImage: "character")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("Target: \(targetWordCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.35))
                }

                Text("Tip: paste your script here, or load one of the built-in test scripts below to validate the reading flows faster.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private func modeCard(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reading setup")
                    .font(.headline)
                    .foregroundStyle(.white)

                Picker("Mode", selection: $model.selectedMode) {
                    ForEach(TeleprompterMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.modeSupportDescription)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.70))

                LazyVGrid(columns: settingColumns(compact: compact), spacing: 10) {
                    settingBadge(title: "Font", value: model.readerFontFamily.label)
                    settingBadge(title: "Highlight", value: model.highlightColorPreset.label)
                    settingBadge(title: "Locale", value: model.speechLocale.label)
                }

                Button {
                    model.startReading()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Reading")
                                .font(.headline)
                            Text("Open the fullscreen teleprompter with the current mode and page.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(model.document.hasAnyContent ? model.highlightColorPreset.tint : Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(!model.document.hasAnyContent)
            }
        }
    }

    private func sampleScriptsCard(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Test scripts")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Use the same scripts from the device checklist to validate core reading flows on your phone.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.68))

                LazyVGrid(columns: sampleColumns(compact: compact), spacing: 12) {
                    ForEach(model.sampleScripts) { sample in
                        Button {
                            model.loadSampleScript(sample)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.headline)
                                    .foregroundStyle(model.highlightColorPreset.tint)
                                    .frame(width: 32, height: 32)
                                    .background(model.highlightColorPreset.softBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sample.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(sample.caption)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.68))
                                    Text(sample.preview)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func tagRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(model.document.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        Button {
                            model.removeTag(tag)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(model.highlightColorPreset.tint.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(model.highlightColorPreset.tint.opacity(0.4), lineWidth: 1))
                }
                Button {
                    showingAddTag = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                        Text(model.document.tags.isEmpty ? "Add tag" : "Tag")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .alert("Add Tag", isPresented: $showingAddTag) {
            TextField("Tag name", text: $newTagText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Add") {
                let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    model.addTag(trimmed)
                }
                newTagText = ""
            }
            Button("Cancel", role: .cancel) {
                newTagText = ""
            }
        } message: {
            Text("Enter a tag to organize this script.")
        }
    }

    private func surfaceCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func actionChip(title: String, systemImage: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(highlighted ? Color.black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: highlighted ? .infinity : nil)
                .background(highlighted ? model.highlightColorPreset.tint : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Adaptive editor toolbar: icon-only on compact screens, icon+label on wide screens.
    /// Groups AI/Practice features into a Menu to prevent overflow.
    @ViewBuilder
    private func editorToolbar(compact: Bool) -> some View {
        if compact {
            compactEditorToolbar()
        } else {
            wideEditorToolbar()
        }
    }

    @ViewBuilder
    private func wideEditorToolbar() -> some View {
        HStack(spacing: 8) {
            if model.document.pages.count > 1 {
                toolbarIcon(systemImage: "arrow.up", disabled: !model.document.hasPreviousPage) {
                    model.moveCurrentPageUp()
                }
                toolbarIcon(systemImage: "arrow.down", disabled: !model.document.hasNextPage) {
                    model.moveCurrentPageDown()
                }
            }
            toolbarIcon(systemImage: "doc.on.doc") { model.duplicateCurrentPage() }
            if model.document.hasAnyContent {
                toolbarIcon(systemImage: "mic") { showingPractice = true }
                toolbarIcon(systemImage: "sparkles") { showingPolish = true }
                toolbarIcon(systemImage: "bubble.left.and.bubble.right") { showingMockQA = true }
                toolbarIcon(systemImage: "doc.on.doc") { model.copyAllTextToClipboard() }
                toolbarIcon(systemImage: "square.and.arrow.up") { model.exportDocument() }
            }
            toolbarIcon(systemImage: "doc.on.clipboard") { model.pasteFromClipboard() }
            toolbarIcon(systemImage: "square.and.arrow.down") { showingDocumentPicker = true }
            toolbarIcon(systemImage: "magnifyingglass") { showingFindReplace = true }
            if model.document.pages.count > 1 {
                toolbarIcon(systemImage: "trash", destructive: true) { showingDeletePageConfirmation = true }
            }
        }
    }

    @ViewBuilder
    private func compactEditorToolbar() -> some View {
        HStack(spacing: 4) {
            if model.document.pages.count > 1 {
                toolbarIcon(systemImage: "arrow.up", disabled: !model.document.hasPreviousPage) {
                    model.moveCurrentPageUp()
                }
                toolbarIcon(systemImage: "arrow.down", disabled: !model.document.hasNextPage) {
                    model.moveCurrentPageDown()
                }
            }
            toolbarIcon(systemImage: "doc.on.doc") { model.duplicateCurrentPage() }
            if model.document.hasAnyContent {
                Menu {
                    Button { showingPractice = true } label: { Label("Practice", systemImage: "mic") }
                    Button { showingPracticeHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                    Button { showingPolish = true } label: { Label("Polish", systemImage: "sparkles") }
                    Button { showingMockQA = true } label: { Label("Mock Q&A", systemImage: "bubble.left.and.bubble.right") }
                    Divider()
                    Button { model.copyAllTextToClipboard() } label: { Label("Copy All", systemImage: "doc.on.doc") }
                    Button { model.exportDocument() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            toolbarIcon(systemImage: "doc.on.clipboard") { model.pasteFromClipboard() }
            toolbarIcon(systemImage: "square.and.arrow.down") { showingDocumentPicker = true }
            toolbarIcon(systemImage: "magnifyingglass") { showingFindReplace = true }
            if model.document.pages.count > 1 {
                toolbarIcon(systemImage: "trash", destructive: true) { showingDeletePageConfirmation = true }
            }
        }
    }

    private func toolbarIcon(systemImage: String, disabled: Bool = false, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(destructive ? .red : (disabled ? .white.opacity(0.35) : .white))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(disabled ? 0.03 : 0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func compactPageButton(title: String, systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(disabled ? 0.03 : 0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func statCapsule(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func settingBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func pagePreview(for page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Empty page"
        }
        return String(trimmed.prefix(80)) + (trimmed.count > 80 ? "…" : "")
    }

    private func pageBackground(for index: Int) -> some ShapeStyle {
        if index == model.document.currentPageIndex {
            return AnyShapeStyle(model.highlightColorPreset.softBackground)
        }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }

    private func confirmNewDocument() {
        if model.hasUnsavedChanges {
            showingNewDocumentConfirmation = true
        } else {
            model.newDocument()
        }
    }

    private func pageColumns(for width: CGFloat) -> [GridItem] {
        let minimum = width >= 900 ? 170 : (width < 390 ? 108 : 128)
        return [GridItem(.adaptive(minimum: CGFloat(minimum)), spacing: 12)]
    }

    private func statColumns(compact: Bool) -> [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 126 : 140), spacing: 10)]
    }

    private func settingColumns(compact: Bool) -> [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 120 : 140), spacing: 10)]
    }

    private func sampleColumns(compact: Bool) -> [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 220 : 250), spacing: 12)]
    }

    private func prefersWideLayout(for width: CGFloat) -> Bool {
        width >= 940 || (horizontalSizeClass == .regular && width >= 820)
    }

    private func isCompactWidth(_ width: CGFloat) -> Bool {
        width < 390
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        if width >= 1024 { return 28 }
        if width < 390 { return 12 }
        return 16
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FindReplaceSheet: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var replaceCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Find") {
                    TextField("Text to find", text: $findText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Replace with") {
                    TextField("Replacement text", text: $replaceText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if replaceCount > 0 {
                    Section {
                        Text("Replaced \(replaceCount) occurrence\(replaceCount == 1 ? "" : "s") on this page.")
                            .foregroundStyle(model.highlightColorPreset.tint)
                    }
                }
                Section {
                    Button {
                        performReplace()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Replace All on This Page")
                        }
                    }
                    .disabled(findText.isEmpty)
                }
            }
            .navigationTitle("Find & Replace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func performReplace() {
        guard !findText.isEmpty else { return }
        let current = model.document.currentPageText
        let newText = current.replacingOccurrences(of: findText, with: replaceText)
        let count = (current.components(separatedBy: findText).count - 1)
        if count > 0 {
            model.updateCurrentPageText(newText)
            replaceCount = count
        }
    }
}

#Preview {
    IOSHomeView(model: IOSTeleprompterModel())
}
