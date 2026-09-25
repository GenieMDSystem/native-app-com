import Foundation

enum ApiError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case missingToken
    case missingProfileFields
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .http(let code, let body): return "Request failed (\(code)): \(body)"
        case .missingToken: return "Login response missing token"
        case .missingProfileFields: return "Profile response missing required fields"
        case .message(let text): return text
        }
    }
}

final class GenieMdApi {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validateLogin(config: AppConfig, username: String, password: String) async throws -> LoginResult {
        let url = URL(string: "\(config.baseUrl)/ivisit.ComV5.00/resources/Email/ValidateLogin/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.refererUrl, forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        try throwIfFailed(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ApiError.invalidResponse
        }
        let token = json["token"] as? String ?? ""
        if token.isEmpty { throw ApiError.missingToken }
        return LoginResult(
            token: token,
            registrationComplete: (json["RegistrationComplete"] as? String) == "true",
            active: json["active"] as? Bool ?? false
        )
    }

    func fetchProfile(config: AppConfig, token: String) async throws -> UserProfileData {
        let url = URL(string: "\(config.baseUrl)/ivisit.ComV5.00/resources/Profile/\(token)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(config.refererUrl, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        try throwIfFailed(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ApiError.invalidResponse
        }
        return try parseProfile(json)
    }

    private func parseProfile(_ json: [String: Any]) throws -> UserProfileData {
        let userID = json["userID"] as? String ?? ""
        let clinicID = json["clinicID"] as? String ?? ""
        let languageId = json["languageId"] as? Int ?? -1
        let oemID = json["oemID"] as? Int ?? -1
        if userID.isEmpty || clinicID.isEmpty || languageId < 0 || oemID < 0 {
            throw ApiError.missingProfileFields
        }

        let displayName: String
        if let screen = json["screenName"] as? String, !screen.isEmpty {
            displayName = screen
        } else if let first = json["firstName"] as? String, !first.isEmpty {
            let last = json["lastName"] as? String ?? ""
            displayName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        } else {
            displayName = (json["userName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? userID
        }

        return UserProfileData(
            userID: userID,
            clinicID: clinicID,
            languageId: languageId,
            oemID: oemID,
            displayName: displayName
        )
    }

    private func throwIfFailed(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ApiError.invalidResponse }
        if (200..<300).contains(http.statusCode) { return }
        let body = String(data: data, encoding: .utf8) ?? ""
        throw ApiError.http(http.statusCode, body)
    }
}
