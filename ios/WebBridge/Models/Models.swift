import Foundation

struct UserProfileData: Equatable, Codable {
    var userID: String
    var clinicID: String
    var languageId: Int
    var oemID: Int
    var displayName: String
}

struct UserSession: Equatable, Codable {
    var token: String
    var profile: UserProfileData
}

struct LoginResult {
    var token: String
    var registrationComplete: Bool
    var active: Bool
}
