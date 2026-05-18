import SwiftUI

/// Wraps IOSDocumentLibraryView for use inside a TabView.
/// Passes an `onDocumentLoaded` callback so the parent can switch to the Home tab.
struct IOSLibraryTabView: View {
    @Bindable var model: IOSTeleprompterModel
    var onDocumentLoaded: (() -> Void)? = nil

    var body: some View {
        IOSDocumentLibraryView(model: model, onDocumentLoaded: onDocumentLoaded)
    }
}
