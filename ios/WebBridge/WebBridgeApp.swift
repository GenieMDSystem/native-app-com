import SwiftUI

@main
struct WebBridgeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .preferredColorScheme(.light)
        }
    }
}
