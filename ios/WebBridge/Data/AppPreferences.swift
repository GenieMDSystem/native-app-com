import Foundation

/// Persists environment config and logged-in user session.
final class AppPreferences {
    static let shared = AppPreferences()

    private let defaults: UserDefaults

    private enum Key {
        static let subdomain = "subdomain"
        static let folder = "folder"
        static let folder2 = "folder_2"
        static let useFolder2 = "use_folder_2"
        static let token = "token"
        static let userID = "user_id"
        static let clinicID = "clinic_id"
        static let languageId = "language_id"
        static let oemID = "oem_id"
        static let displayName = "display_name"
        static let localMode = "local_mode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasConfig: Bool {
        defaults.object(forKey: Key.subdomain) != nil &&
            defaults.object(forKey: Key.folder) != nil
    }

    func getConfig() -> AppConfig? {
        guard
            let subdomain = defaults.string(forKey: Key.subdomain),
            let folder = defaults.string(forKey: Key.folder)
        else { return nil }
        let folder2 = defaults.string(forKey: Key.folder2)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return AppConfig(
            subdomain: subdomain,
            folder: folder,
            folder2: (folder2?.isEmpty == false) ? folder2 : nil
        )
    }

    func saveConfig(subdomain: String, folder: String, folder2: String? = nil) {
        defaults.set(subdomain.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.subdomain)
        defaults.set(folder.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.folder)
        let secondary = folder2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if secondary.isEmpty {
            defaults.removeObject(forKey: Key.folder2)
            defaults.set(false, forKey: Key.useFolder2)
        } else {
            defaults.set(secondary, forKey: Key.folder2)
        }
    }

    var isLoggedIn: Bool {
        let token = defaults.string(forKey: Key.token) ?? ""
        let userID = defaults.string(forKey: Key.userID) ?? ""
        return !token.isEmpty && !userID.isEmpty
    }

    func getSession() -> UserSession? {
        guard
            let token = defaults.string(forKey: Key.token),
            let userID = defaults.string(forKey: Key.userID),
            let clinicID = defaults.string(forKey: Key.clinicID)
        else { return nil }

        let languageId = defaults.integer(forKey: Key.languageId)
        let oemID = defaults.integer(forKey: Key.oemID)
        guard defaults.object(forKey: Key.languageId) != nil,
              defaults.object(forKey: Key.oemID) != nil,
              languageId >= 0,
              oemID >= 0
        else { return nil }

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
        defaults.set(profile.userID, forKey: Key.userID)
        defaults.set(profile.clinicID, forKey: Key.clinicID)
        defaults.set(profile.languageId, forKey: Key.languageId)
        defaults.set(profile.oemID, forKey: Key.oemID)
        defaults.set(profile.displayName, forKey: Key.displayName)
    }

    /// Clears login token and profile; keeps environment config.
    func clearSession() {
        defaults.removeObject(forKey: Key.token)
        defaults.removeObject(forKey: Key.userID)
        defaults.removeObject(forKey: Key.clinicID)
        defaults.removeObject(forKey: Key.languageId)
        defaults.removeObject(forKey: Key.oemID)
        defaults.removeObject(forKey: Key.displayName)
    }

    var isLocalMode: Bool {
        get { defaults.bool(forKey: Key.localMode) }
        set { defaults.set(newValue, forKey: Key.localMode) }
    }

    /// When true and folder2 is set, WebView URLs use folder2.
    var isUsingFolder2: Bool {
        get { defaults.bool(forKey: Key.useFolder2) }
        set { defaults.set(newValue, forKey: Key.useFolder2) }
    }

    func clearAll() {
        [
            Key.subdomain, Key.folder, Key.folder2, Key.useFolder2,
            Key.token, Key.userID, Key.clinicID, Key.languageId,
            Key.oemID, Key.displayName, Key.localMode
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
