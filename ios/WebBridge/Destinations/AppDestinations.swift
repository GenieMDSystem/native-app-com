import Foundation

/// Builds WebView URLs from saved environment + logged-in profile.
/// Uses `fromWebView=ios` (Android uses `android`).
enum AppDestinations {
    private static let platform = "ios"

    /// Waiting room / Visit Doctor Now
    static func visitDoctorUrl(config: AppConfig, profile: UserProfileData) -> String {
        var url = "\(config.baseUrl)/\(config.folder)/assessment/#/protocol/"
        url += "\(profile.clinicID)/consent/\(profile.userID)"
        url += "?patientLanguageID=\(profile.languageId)"
        url += "&patientOEMID=\(profile.oemID)"
        url += "&protocolName=Revamp%20TeleConsultation"
        url += "&dependent=true"
        url += "&fromWebView=\(platform)"
        url += "&ignoreLocationCheck=true"
        url += "&disableCamera=true"
        url += "&forWR=true"
        return url
    }

    /// Schedule a teleconsultation
    static func scheduleVisitUrl(config: AppConfig, profile: UserProfileData) -> String {
        var url = "\(config.baseUrl)/\(config.folder)/assessment/#/protocol/"
        url += "\(profile.clinicID)/consent/\(profile.userID)"
        url += "?patientLanguageID=\(profile.languageId)"
        url += "&patientOEMID=\(profile.oemID)"
        url += "&protocolName=Revamp%20Scheudle%20a%20TeleConsultation"
        url += "&dependent=true"
        url += "&fromWebView=\(platform)"
        url += "&ignoreLocationCheck=true"
        url += "&disableCamera=true"
        return url
    }

    /// Schedules list
    static func schedulesListUrl(config: AppConfig, profile: UserProfileData) -> String {
        "\(config.baseUrl)/\(config.folder)/rpm/#/webview/\(profile.clinicID)/\(profile.userID)/patient-schedule?fromWebView=\(platform)"
    }
}
