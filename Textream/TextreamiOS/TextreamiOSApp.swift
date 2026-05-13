import SwiftUI

@main
struct TextreamiOSApp: App {
    @State private var model = IOSTeleprompterModel()

    var body: some Scene {
        WindowGroup {
            IOSHomeView(model: model)
        }
    }
}
