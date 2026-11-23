import Foundation
import Observation

enum AppRoute: Equatable {
    case splash
    case setup
    case login
    case home
    case webView(url: String, showCloseButton: Bool)
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

    /// When true, Visit Doctor / Schedule Visit use localhost:4201 and
    /// Schedules List uses localhost:4200/rpm.
    var useLocalWebHost: Bool {
        didSet {
            if AppDestinations.isLocalHostEnabled {
                prefs.isLocalMode = useLocalWebHost
            }
        }
    }

    /// When true and folder2 is configured, WebView URLs use folder2.
    var useFolder2: Bool {
        didSet {
            prefs.isUsingFolder2 = useFolder2
        }
    }

    private let prefs: AppPreferences
    private let api: GenieMdApi

    init(prefs: AppPreferences = .shared, api: GenieMdApi = GenieMdApi()) {
        self.prefs = prefs
        self.api = api
        self.config = prefs.getConfig()
        self.session = prefs.getSession()
        self.useLegacyWebView = UserDefaults.standard.bool(forKey: "use_legacy_webview")
        self.useLocalWebHost = AppDestinations.isLocalHostEnabled && prefs.isLocalMode
        self.useFolder2 = (prefs.getConfig()?.hasFolder2 == true) && prefs.isUsingFolder2
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

    func saveSetup(subdomain: String, folder: String, folder2: String? = nil) {
        prefs.saveConfig(subdomain: subdomain, folder: folder, folder2: folder2)
        config = prefs.getConfig()
        if config?.hasFolder2 != true {
            useFolder2 = false
        }
        showToast("Environment saved")
        route = .login
    }

    /// Config with the Home folder switch applied.
    var activeConfig: AppConfig? {
        guard let config else { return nil }
        return config.withActiveFolder(useFolder2: useFolder2 && config.hasFolder2)
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

    func openWebView(url: String, showCloseButton: Bool = false) {
        route = .webView(url: url, showCloseButton: showCloseButton)
    }

    func closeWebView() {
        route = .home
    }

    func showToast(_ message: String) {
        toastMessage = message
    }
}
