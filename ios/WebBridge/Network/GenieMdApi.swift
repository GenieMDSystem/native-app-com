import Foundation

enum ApiError: LocalizedError {
    case invalidURL
    case http(status: Int, body: String)
    case missingToken
    case missingProfileFields
    case decoding
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .http(let status, let body):
            return "Request failed (\(status)): \(body)"
        case .missingToken:
            return "Login response missing token"
        case .missingProfileFields:
            return "Profile response missing required fields"
        case .decoding:
            return "Could not parse server response"
        case .network(let error):
            return error.localizedDescription
        }
    }
}

final class GenieMdApi {
    private let session: URLSession

    init(session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()) {
        self.session = session
    }

    /// POST /ivisit.ComV5.00/resources/Email/ValidateLogin/
    func validateLogin(config: AppConfig, username: String, password: String) async throws -> LoginResult {
        let urlString = "\(config.baseUrl)/ivisit.ComV5.00/resources/Email/ValidateLogin/"
        guard let url = URL(string: urlString) else { throw ApiError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.refererUrl, forHTTPHeaderField: "Referer")

        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data, label: "Login")

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["token"] as? String,
            !token.isEmpty
        else { throw ApiError.missingToken }

        let registrationComplete = (json["RegistrationComplete"] as? String) == "true"
        let active = json["active"] as? Bool ?? false

        return LoginResult(
            token: token,
            registrationComplete: registrationComplete,
            active: active
        )
    }

    /// GET /ivisit.ComV5.00/resources/Profile/{token}
    func fetchProfile(config: AppConfig, token: String) async throws -> UserProfileData {
        let urlString = "\(config.baseUrl)/ivisit.ComV5.00/resources/Profile/\(token)"
        guard let url = URL(string: urlString) else { throw ApiError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue(config.refererUrl, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data, label: "Profile")

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ApiError.decoding
        }
        return try parseProfile(json)
    }

    private func parseProfile(_ json: [String: Any]) throws -> UserProfileData {
        let userID = json["userID"] as? String ?? ""
        let clinicID = json["clinicID"] as? String ?? ""
        let languageId = json["languageId"] as? Int ?? -1
        let oemID = json["oemID"] as? Int ?? -1

        guard !userID.isEmpty, !clinicID.isEmpty, languageId >= 0, oemID >= 0 else {
            throw ApiError.missingProfileFields
        }

        let displayName: String
        if let screenName = json["screenName"] as? String, !screenName.isEmpty {
            displayName = screenName
        } else if let firstName = json["firstName"] as? String, !firstName.isEmpty {
            let lastName = json["lastName"] as? String ?? ""
            displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
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

    private func validateHTTP(response: URLResponse, data: Data, label: String) throws {
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ApiError.http(status: http.statusCode, body: "\(label) failed: \(body)")
        }
    }
}
