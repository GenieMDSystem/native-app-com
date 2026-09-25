import SwiftUI

@main
struct WebViewBrowserBridgeApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
        }
    }
}

final class SessionStore: ObservableObject {
    @Published var config: AppConfig?
    @Published var session: UserSession?

    init() {
        refresh()
    }

    func refresh() {
        config = AppPreferences.shared.getConfig()
        session = AppPreferences.shared.getSession()
    }

    func logout() {
        AppPreferences.shared.clearSession()
        session = nil
    }
}

struct RootView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var hasConfig = AppPreferences.shared.hasConfig

    var body: some View {
        Group {
            if !hasConfig || store.config == nil {
                SetupView(hasConfig: $hasConfig)
                    .onChange(of: hasConfig) { _ in
                        store.refresh()
                    }
            } else if store.session == nil, let config = store.config {
                LoginView(config: config) {
                    store.refresh()
                }
            } else if let config = store.config, let session = store.session {
                HomeView(config: config, session: session) {
                    store.logout()
                }
            }
        }
        .tint(Color(red: 0.08, green: 0.40, blue: 0.75))
    }
}
