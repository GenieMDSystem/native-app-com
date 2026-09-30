import Foundation

/// Builds WebView URLs from saved environment + logged-in profile.
/// Uses `fromWebView=ios` (Android uses `android`).
enum AppDestinations {
    private static let platform = "ios"

    static let localAssessmentBase = "http://localhost:4201"
    static let localRpmBase = "http://localhost:4200/rpm"

    private static func assessmentBase(config: AppConfig, useLocal: Bool) -> String {
        useLocal ? localAssessmentBase : "\(config.baseUrl)/\(config.folder)/assessment"
    }

    private static func rpmBase(config: AppConfig, useLocal: Bool) -> String {
        useLocal ? localRpmBase : "\(config.baseUrl)/\(config.folder)/rpm"
    }

    /// Waiting room / Visit Doctor Now
    /// live:  https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/...
    /// local: http://localhost:4201/#/protocol/...
    static func visitDoctorUrl(config: AppConfig, profile: UserProfileData, useLocal: Bool = false) -> String {
        var url = "\(assessmentBase(config: config, useLocal: useLocal))/#/protocol/"
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
    static func scheduleVisitUrl(config: AppConfig, profile: UserProfileData, useLocal: Bool = false) -> String {
        var url = "\(assessmentBase(config: config, useLocal: useLocal))/#/protocol/"
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
    /// live:  https://{subdomain}.geniemd.net/{folder}/rpm/#/webview/...
    /// local: http://localhost:4200/rpm/#/webview/...
    static func schedulesListUrl(config: AppConfig, profile: UserProfileData, useLocal: Bool = false) -> String {
        "\(rpmBase(config: config, useLocal: useLocal))/#/webview/\(profile.clinicID)/\(profile.userID)/patient-schedule?fromWebView=\(platform)"
    }
}
