import Foundation

/// Server environment saved on first launch.
/// Full domain: https://{subdomain}.geniemd.net/{folder}/...
struct AppConfig: Equatable, Codable {
    var subdomain: String
    var folder: String

    var baseUrl: String { "https://\(subdomain).geniemd.net" }

    /// Display / path base, e.g. https://mhc.geniemd.net/apps2
    var environmentUrl: String { "\(baseUrl)/\(folder)" }

    var refererUrl: String { "\(baseUrl)/\(folder)/rpm/" }
}
