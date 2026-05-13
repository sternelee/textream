import SwiftUI

struct IOSHomeView: View {
    @Bindable var model: IOSTeleprompterModel
    @State private var showingSettings = false
    @State private var showingLibrary = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                pagePicker
                editorCard
                controls
                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("Textream")
            .sheet(isPresented: $showingSettings) {
                IOSSettingsView(model: model)
            }
            .sheet(isPresented: $showingLibrary) {
                IOSDocumentLibraryView(model: model)
            }
            .fullScreenCover(isPresented: $model.isReaderPresented) {
                IOSReaderView(model: model)
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

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Script title", text: $model.pageTitle)
                    .textFieldStyle(.roundedBorder)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
            }

            HStack(spacing: 10) {
                actionChip(title: "New", systemImage: "plus.square.on.square") {
                    model.newDocument()
                }
                actionChip(title: "Open", systemImage: "folder") {
                    showingLibrary = true
                }
                actionChip(title: "Save", systemImage: "square.and.arrow.down") {
                    model.saveDocument()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let status = model.documentStatusMessage {
                Label(status, systemImage: model.presentedErrorMessage == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(model.presentedErrorMessage == nil ? .secondary : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var pagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(model.document.pages.enumerated()), id: \.offset) { index, _ in
                    Button {
                        model.jumpToPage(index)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.headline)
                            Text(model.document.pagePreview(at: index))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(width: 110)
                        .background(index == model.document.currentPageIndex ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(index == model.document.currentPageIndex ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    model.addPage()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Page \(model.document.currentPageIndex + 1)")
                    .font(.headline)
                Spacer()
                if model.document.pages.count > 1 {
                    Button(role: .destructive) {
                        model.removeCurrentPage()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            TextEditor(text: Binding(
                get: { model.document.currentPageText },
                set: { model.updateCurrentPageText($0) }
            ))
            .frame(minHeight: 280)
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $model.selectedMode) {
                ForEach(TeleprompterMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(model.modeSupportDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.startReading()
            } label: {
                Text("Start Reading")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.document.hasAnyContent)
        }
    }

    private func actionChip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IOSHomeView(model: IOSTeleprompterModel())
}
