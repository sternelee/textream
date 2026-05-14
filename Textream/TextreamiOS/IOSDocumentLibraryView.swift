import SwiftUI

struct IOSDocumentLibraryView: View {
    @Bindable var model: IOSTeleprompterModel
    @Environment(\.dismiss) private var dismiss
    @State private var documentPendingDeletion: SavedScriptDocument?
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .modifiedDescending
    @State private var isEditing = false
    @State private var selectedDocuments = Set<URL>()
    @State private var selectedTagFilter: String? = nil

    enum SortOrder: String, CaseIterable, Identifiable {
        case name = "Name"
        case modifiedDescending = "Recent"
        case modifiedAscending = "Oldest"

        var id: String { rawValue }
        var label: String { rawValue }
    }

    private var allTags: [String] {
        Array(Set(model.documentLibrary.documents.flatMap { $0.tags })).sorted()
    }

    private var filteredDocuments: [SavedScriptDocument] {
        var docs = model.documentLibrary.documents
        if let tag = selectedTagFilter {
            docs = docs.filter { $0.tags.contains(tag) }
        }
        if !searchText.isEmpty {
            docs = docs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .name:
            return docs.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .modifiedDescending:
            return docs.sorted { $0.modifiedAt > $1.modifiedAt }
        case .modifiedAscending:
            return docs.sorted { $0.modifiedAt < $1.modifiedAt }
        }
    }

    private func batchDeleteSelected() {
        let toDelete = model.documentLibrary.documents.filter { selectedDocuments.contains($0.url) }
        for item in toDelete {
            model.deleteDocument(item)
        }
        selectedDocuments.removeAll()
        isEditing = false
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.documentLibrary.documents.isEmpty {
                    ContentUnavailableView {
                        Label("No Saved Scripts", systemImage: "doc.text")
                    } description: {
                        Text("Save a script from the editor, or load a test script to get started.")
                    } actions: {
                        Button {
                            model.newDocument()
                            dismiss()
                        } label: {
                            Label("Create New Script", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            if let firstSample = model.sampleScripts.first {
                                model.loadSampleScript(firstSample)
                            }
                            dismiss()
                        } label: {
                            Label("Load Test Script", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            dismiss()
                        } label: {
                            Label("Back to Editor", systemImage: "arrow.left")
                        }
                        .buttonStyle(.bordered)
                    }
                } else if filteredDocuments.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text(selectedTagFilter != nil ? "No scripts match the selected tag." : "No scripts match your search. Try a different keyword.")
                    } actions: {
                        if selectedTagFilter != nil {
                            Button {
                                selectedTagFilter = nil
                            } label: {
                                Label("Clear Filter", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Button {
                            searchText = ""
                            selectedTagFilter = nil
                        } label: {
                            Label("Clear All", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List {
                        ForEach(filteredDocuments) { item in
                            Button {
                                if isEditing {
                                    if selectedDocuments.contains(item.url) {
                                        selectedDocuments.remove(item.url)
                                    } else {
                                        selectedDocuments.insert(item.url)
                                    }
                                } else {
                                    model.loadDocument(item)
                                    dismiss()
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    if isEditing {
                                        Image(systemName: selectedDocuments.contains(item.url) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selectedDocuments.contains(item.url) ? model.highlightColorPreset.tint : .secondary)
                                            .frame(width: 28, height: 28)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(item.title)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            if !isEditing, item.url == model.currentDocumentURL {
                                                Text("OPEN")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(model.highlightColorPreset.tint)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(model.highlightColorPreset.softBackground)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text(item.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text("\(item.pageCount) pages · \(item.wordCount) words")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if !item.tags.isEmpty {
                                            HStack(spacing: 4) {
                                                ForEach(item.tags.prefix(3), id: \.self) { tag in
                                                    Text(tag)
                                                        .font(.caption2.weight(.medium))
                                                        .foregroundStyle(.white.opacity(0.8))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(model.highlightColorPreset.tint.opacity(0.25))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }

                                        if !isEditing, let lastPage = item.lastReadPageIndex, lastPage >= 0, item.pageCount > 0 {
                                            let pct = min(100, Int((Double(lastPage + 1) / Double(item.pageCount)) * 100))
                                            Text("Continue from page \(lastPage + 1) · \(pct)%")
                                                .font(.caption2)
                                                .foregroundStyle(model.highlightColorPreset.tint)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if !isEditing {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if !isEditing {
                                    Button(role: .destructive) {
                                        documentPendingDeletion = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .contextMenu {
                                if !isEditing {
                                    Button {
                                        model.loadDocument(item)
                                        dismiss()
                                    } label: {
                                        Label("Open", systemImage: "doc.text")
                                    }
                                    Button {
                                        let fullText = item.title
                                        UIPasteboard.general.string = fullText
                                    } label: {
                                        Label("Copy Title", systemImage: "doc.on.doc")
                                    }
                                    Button(role: .destructive) {
                                        documentPendingDeletion = item
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        model.refreshDocuments()
                    }
                }
            }
            .navigationTitle("Saved Scripts")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search scripts")
            .alert("Delete script?", isPresented: Binding(
                get: { documentPendingDeletion != nil },
                set: { if !$0 { documentPendingDeletion = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let documentPendingDeletion {
                        model.deleteDocument(documentPendingDeletion)
                        self.documentPendingDeletion = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    documentPendingDeletion = nil
                }
            } message: {
                Text(documentPendingDeletion.map { "Delete \($0.title).textream from local storage?" } ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") {
                            isEditing = false
                            selectedDocuments.removeAll()
                        }
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button {
                            batchDeleteSelected()
                        } label: {
                            Text("Delete (\(selectedDocuments.count))")
                        }
                        .disabled(selectedDocuments.isEmpty)
                    } else {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(SortOrder.allCases) { order in
                                    Text(order.label).tag(order)
                                }
                            }
                            if !allTags.isEmpty {
                                Divider()
                                Menu("Filter by Tag") {
                                    Button {
                                        selectedTagFilter = nil
                                    } label: {
                                        Label("All", systemImage: selectedTagFilter == nil ? "checkmark" : "")
                                    }
                                    ForEach(allTags, id: \.self) { tag in
                                        Button {
                                            selectedTagFilter = tag
                                        } label: {
                                            Label(tag, systemImage: selectedTagFilter == tag ? "checkmark" : "")
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button {
                                model.refreshDocuments()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            Divider()
                            Button {
                                isEditing = true
                            } label: {
                                Label("Select Multiple", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    IOSDocumentLibraryView(model: IOSTeleprompterModel())
}
