import Foundation

final class AppPreferences {
    static let shared = AppPreferences()

    private let defaults: UserDefaults
    private let suiteName = "webview_bridge_cache"

    private enum Key {
        static let subdomain = "subdomain"
        static let folder = "folder"
        static let token = "token"
        static let userId = "user_id"
        static let clinicId = "clinic_id"
        static let languageId = "language_id"
        static let oemId = "oem_id"
        static let displayName = "display_name"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasConfig: Bool {
        defaults.string(forKey: Key.subdomain) != nil && defaults.string(forKey: Key.folder) != nil
    }

    var isLoggedIn: Bool {
        let token = defaults.string(forKey: Key.token) ?? ""
        let userId = defaults.string(forKey: Key.userId) ?? ""
        return !token.isEmpty && !userId.isEmpty
    }

    func getConfig() -> AppConfig? {
        guard let subdomain = defaults.string(forKey: Key.subdomain),
              let folder = defaults.string(forKey: Key.folder) else { return nil }
        return AppConfig(subdomain: subdomain, folder: folder)
    }

    func saveConfig(subdomain: String, folder: String) {
        defaults.set(subdomain.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.subdomain)
        defaults.set(folder.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.folder)
    }

    func getSession() -> UserSession? {
        guard let token = defaults.string(forKey: Key.token),
              let userID = defaults.string(forKey: Key.userId),
              let clinicID = defaults.string(forKey: Key.clinicId) else { return nil }
        let languageId = defaults.integer(forKey: Key.languageId)
        let oemID = defaults.integer(forKey: Key.oemId)
        if languageId < 0 || oemID < 0 { return nil }
        let displayName = defaults.string(forKey: Key.displayName) ?? ""
        return UserSession(
            token: token,
            profile: UserProfileData(
                userID: userID,
                clinicID: clinicID,
                languageId: languageId,
                oemID: oemID,
                displayName: displayName
            )
        )
    }

    func saveSession(token: String, profile: UserProfileData) {
        defaults.set(token, forKey: Key.token)
        defaults.set(profile.userID, forKey: Key.userId)
        defaults.set(profile.clinicID, forKey: Key.clinicId)
        defaults.set(profile.languageId, forKey: Key.languageId)
        defaults.set(profile.oemID, forKey: Key.oemId)
        defaults.set(profile.displayName, forKey: Key.displayName)
    }

    func clearSession() {
        [Key.token, Key.userId, Key.clinicId, Key.languageId, Key.oemId, Key.displayName].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
