import Foundation

/// Server environment saved on first launch.
/// Full domain: https://{subdomain}.geniemd.net/{folder}/...
///
/// `folder` is required. `folder2` is optional — when set, Home shows a
/// Folder1 ⇄ Folder2 switch (same pattern as Live ⇄ Local).
struct AppConfig: Equatable, Codable {
    var subdomain: String
    var folder: String
    var folder2: String?

    var baseUrl: String { "https://\(subdomain).geniemd.net" }

    var hasFolder2: Bool {
        !(folder2?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func activeFolder(useFolder2: Bool) -> String {
        if useFolder2, let second = folder2?.trimmingCharacters(in: .whitespacesAndNewlines), !second.isEmpty {
            return second
        }
        return folder
    }

    func withActiveFolder(useFolder2: Bool) -> AppConfig {
        AppConfig(subdomain: subdomain, folder: activeFolder(useFolder2: useFolder2), folder2: folder2)
    }

    /// Display / path base for the selected folder, e.g. https://mhc.geniemd.net/apps1
    func environmentUrl(useFolder2: Bool = false) -> String {
        "\(baseUrl)/\(activeFolder(useFolder2: useFolder2))"
    }

    /// Primary-folder display (login / default).
    var environmentUrl: String { environmentUrl(useFolder2: false) }

    var refererUrl: String { "\(baseUrl)/\(folder)/rpm/" }
}
