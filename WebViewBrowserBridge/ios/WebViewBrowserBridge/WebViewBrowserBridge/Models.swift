import Foundation

struct AppConfig: Equatable {
    var subdomain: String
    var folder: String

    var baseUrl: String { "https://\(subdomain).geniemd.net" }
    var environmentUrl: String { "\(baseUrl)/\(folder)" }
    var refererUrl: String { "\(baseUrl)/\(folder)/rpm/" }
}

struct UserProfileData: Equatable {
    var userID: String
    var clinicID: String
    var languageId: Int
    var oemID: Int
    var displayName: String
}

struct UserSession: Equatable {
    var token: String
    var profile: UserProfileData
}

struct LoginResult {
    var token: String
    var registrationComplete: Bool
    var active: Bool
}

enum BridgeAction: Int {
    case waitingRoom = 1
    case schedule = 2
    case openScheduleLink = 3
}
