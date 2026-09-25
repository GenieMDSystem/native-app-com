import Foundation
import Observation

enum AppRoute: Equatable {
    case splash
    case setup
    case login
    case home
    case webView(url: String)
}

@Observable
final class AppState {
    var route: AppRoute = .splash
    var toastMessage: String?
    var config: AppConfig?
    var session: UserSession?

    /// When true, opens the legacy hybrid WebView (UIImagePickerController + main-thread inject)
    /// to help reproduce Photo Library dismiss freezes seen in client apps.
    var useLegacyWebView: Bool {
        didSet { UserDefaults.standard.set(useLegacyWebView, forKey: "use_legacy_webview") }
    }

    private let prefs: AppPreferences
    private let api: GenieMdApi

    init(prefs: AppPreferences = .shared, api: GenieMdApi = GenieMdApi()) {
        self.prefs = prefs
        self.api = api
        self.config = prefs.getConfig()
        self.session = prefs.getSession()
        self.useLegacyWebView = UserDefaults.standard.bool(forKey: "use_legacy_webview")
    }

    @MainActor
    func resolveInitialRoute() async {
        // Brief splash so launch feels intentional (mirrors LauncherActivity routing)
        try? await Task.sleep(for: .milliseconds(900))

        if prefs.hasConfig == false {
            route = .setup
        } else if prefs.isLoggedIn == false {
            config = prefs.getConfig()
            route = .login
        } else {
            config = prefs.getConfig()
            session = prefs.getSession()
            route = .home
        }
    }

    func saveSetup(subdomain: String, folder: String) {
        prefs.saveConfig(subdomain: subdomain, folder: folder)
        config = prefs.getConfig()
        showToast("Environment saved")
        route = .login
    }

    @MainActor
    func login(username: String, password: String) async throws {
        guard let config else { throw ApiError.invalidURL }
        let login = try await api.validateLogin(config: config, username: username, password: password)
        let profile = try await api.fetchProfile(config: config, token: login.token)
        prefs.saveSession(token: login.token, profile: profile)
        session = prefs.getSession()
        route = .home
    }

    func logout() {
        prefs.clearSession()
        session = nil
        route = .login
    }

    func openWebView(url: String) {
        route = .webView(url: url)
    }

    func closeWebView() {
        route = .home
    }

    func showToast(_ message: String) {
        toastMessage = message
    }
}
