import SwiftUI

@main
struct TextreamiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = IOSTeleprompterModel()

    var body: some Scene {
        WindowGroup {
            IOSHomeView(model: model)
                .preferredColorScheme(model.forceDarkMode ? .dark : nil)
                .onChange(of: scenePhase) { _, newValue in
                    model.handleScenePhaseChange(newValue)
                }
        }
    }
}
