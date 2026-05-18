import SwiftUI

struct IOSEditorView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeletePageConfirmation = false
    @State private var showingPolish = false
    @State private var showingPractice = false
    @State private var showingPracticeHistory = false
    @State private var showingMockQA = false
    @State private var showingDocumentPicker = false
    @State private var showAutoSaveIndicator = false
    @State private var autoSaveTimer: Timer?
    @State private var newTagText = ""
    @State private var showingAddTag = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compact = proxy.size.width < 390
                ScrollView {
                    VStack(spacing: 16) {
                        editorSection(compact: compact)
                        pageGridSection(width: proxy.size.width)
                        sampleScriptsSection(compact: compact)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(backgroundGradient.ignoresSafeArea())
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("Edit Script")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(model.highlightColorPreset.tint)
                }
                ToolbarItem(placement: .primaryAction) {
                    editorMenuButton(compact: true)
                }
            }
            .onChange(of: model.lastAutoSavedAt) { _, _ in
                showAutoSaveIndicator = true
                autoSaveTimer?.invalidate()
                autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    withAnimation { showAutoSaveIndicator = false }
                }
            }
            .sheet(isPresented: $showingPolish) {
                AIPolishView(selectedText: model.document.currentPageText) { polished in
                    model.updateCurrentPageText(polished)
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
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { url in
                    model.importDocument(from: url)
                }
            }
            .sheet(isPresented: $model.isExportSheetPresented, onDismiss: {
                model.clearExportURL()
            }) {
                if let url = model.exportDocumentURL {
                    ActivityView(activityItems: [url])
                }
            }
            .confirmationDialog("Delete current page?", isPresented: $showingDeletePageConfirmation, titleVisibility: .visible) {
                Button("Delete Page", role: .destructive) { model.removeCurrentPage() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes page \(model.document.currentPageIndex + 1). Textream will keep the remaining pages.")
            }
        }
    }

    // MARK: - Editor Section

    private func editorSection(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                // Title + status
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
                    compactEditorToolbarIcons()
                }

                tagRow()

                // Page navigation
                HStack(spacing: 10) {
                    compactPageButton(title: "Prev", systemImage: "chevron.left",
                                      disabled: !model.document.hasPreviousPage) {
                        model.goToPreviousPage()
                    }
                    compactPageButton(title: "Next", systemImage: "chevron.right",
                                      disabled: !model.document.hasNextPage) {
                        model.goToNextPage()
                    }
                    Text(model.document.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "Current page is empty"
                         : "Page \(model.document.currentPageIndex + 1) of \(model.document.pages.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Text editor
                TextEditor(text: Binding(
                    get: { model.document.currentPageText },
                    set: { model.updateCurrentPageText($0) }
                ))
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.white)
                .frame(minHeight: 280)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Clear") { model.updateCurrentPageText("") }
                            .foregroundStyle(Color.red.opacity(0.8))
                        Button("Line Break") {
                            model.updateCurrentPageText(model.document.currentPageText + "\n")
                        }
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.bold)
                    }
                }

                // Word count progress
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
            }
        }
    }

    // MARK: - Page Grid

    private func pageGridSection(width: CGFloat) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pages")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Tap a page to switch to it.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button { model.addPage() } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.highlightColorPreset.tint)
                    }
                    .buttonStyle(.plain)
                }

                let minSize: CGFloat = width < 390 ? 108 : 128
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minSize), spacing: 12)], spacing: 12) {
                    ForEach(Array(model.document.pages.enumerated()), id: \.offset) { index, page in
                        Button { model.jumpToPage(index) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Page \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 0)
                                    Image(systemName: model.document.readPages.contains(index)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(model.document.readPages.contains(index)
                                                         ? model.highlightColorPreset.tint : .white.opacity(0.35))
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
                            .background(index == model.document.currentPageIndex
                                        ? AnyShapeStyle(model.highlightColorPreset.softBackground)
                                        : AnyShapeStyle(Color.white.opacity(0.05)))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(index == model.document.currentPageIndex
                                            ? model.highlightColorPreset.tint.opacity(0.7) : .white.opacity(0.06),
                                            lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sample Scripts

    private func sampleScriptsSection(compact: Bool) -> some View {
        surfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Test scripts")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Load a sample script to try out the reading modes.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.68))

                let minSize: CGFloat = compact ? 220 : 250
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minSize), spacing: 12)], spacing: 12) {
                    ForEach(model.sampleScripts) { sample in
                        Button { model.loadSampleScript(sample) } label: {
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

    // MARK: - Tag Row

    private func tagRow() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(model.document.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        Button { model.removeTag(tag) } label: {
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
                Button { showingAddTag = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption2.weight(.bold))
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
                if !trimmed.isEmpty { model.addTag(trimmed) }
                newTagText = ""
            }
            Button("Cancel", role: .cancel) { newTagText = "" }
        } message: {
            Text("Enter a tag to organize this script.")
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func compactEditorToolbarIcons() -> some View {
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
            Menu {
                if model.document.hasAnyContent {
                    Button { showingPractice = true } label: { Label("Practice", systemImage: "mic") }
                    Button { showingPracticeHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                    Button { showingPolish = true } label: { Label("Polish", systemImage: "sparkles") }
                    Button { showingMockQA = true } label: { Label("Mock Q&A", systemImage: "bubble.left.and.bubble.right") }
                    Divider()
                    Button { model.copyAllTextToClipboard() } label: { Label("Copy All", systemImage: "doc.on.doc") }
                    Button { model.exportDocument() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    Divider()
                }
                Button { model.pasteFromClipboard() } label: { Label("Paste from Clipboard", systemImage: "doc.on.clipboard") }
                Button { showingDocumentPicker = true } label: { Label("Import File", systemImage: "square.and.arrow.down") }
                if model.document.pages.count > 1 {
                    Divider()
                    Button(role: .destructive) { showingDeletePageConfirmation = true } label: {
                        Label("Delete Page", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    @ViewBuilder
    private func editorMenuButton(compact: Bool) -> some View {
        Menu {
            Button { model.saveDocument() } label: {
                Label(model.hasUnsavedChanges ? "Save*" : "Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
        } label: {
            Image(systemName: model.hasUnsavedChanges ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                .foregroundStyle(model.hasUnsavedChanges ? model.highlightColorPreset.tint : .white)
        }
    }

    // MARK: - Helpers

    private func toolbarIcon(systemImage: String, disabled: Bool = false, destructive: Bool = false,
                              action: @escaping () -> Void) -> some View {
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

    private func compactPageButton(title: String, systemImage: String, disabled: Bool,
                                    action: @escaping () -> Void) -> some View {
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

    private func surfaceCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func pagePreview(for page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty page" }
        return String(trimmed.prefix(80)) + (trimmed.count > 80 ? "…" : "")
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
}

#Preview {
    IOSEditorView(model: IOSTeleprompterModel())
}
