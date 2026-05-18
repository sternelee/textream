import SwiftUI

@main
struct TextreamiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = IOSTeleprompterModel()

    var body: some Scene {
        WindowGroup {
            IOSRootTabView(model: model)
                .preferredColorScheme(model.forceDarkMode ? .dark : nil)
                .onChange(of: scenePhase) { _, newValue in
                    model.handleScenePhaseChange(newValue)
                }
        }
    }
}

struct IOSRootTabView: View {
    @Bindable var model: IOSTeleprompterModel
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            IOSHomeView(model: model, switchToLibraryTab: { selectedTab = 1 })
                .tabItem { Label("Home", systemImage: "play.circle.fill") }
                .tag(0)

            IOSLibraryTabView(model: model, onDocumentLoaded: { selectedTab = 0 })
                .tabItem { Label("Library", systemImage: "doc.text.fill") }
                .tag(1)

            IOSSettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
        .tint(Color.accentColor)
    }
}
