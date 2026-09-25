import Foundation

enum AppDestinations {
    /// Waiting room — iOS uses `fromWebView=ios`.
    static func visitDoctorUrl(config: AppConfig, profile: UserProfileData) -> String {
        "\(config.baseUrl)/\(config.folder)/assessment/#/protocol/\(profile.clinicID)/consent/\(profile.userID)"
            + "?patientLanguageID=\(profile.languageId)"
            + "&patientOEMID=\(profile.oemID)"
            + "&protocolName=Revamp%20TeleConsultation"
            + "&dependent=true"
            + "&fromWebView=ios"
            + "&ignoreLocationCheck=true"
            + "&disableCamera=true"
            + "&forWR=true"
    }

    static func scheduleVisitUrl(config: AppConfig, profile: UserProfileData) -> String {
        "\(config.baseUrl)/\(config.folder)/assessment/#/protocol/\(profile.clinicID)/consent/\(profile.userID)"
            + "?patientLanguageID=\(profile.languageId)"
            + "&patientOEMID=\(profile.oemID)"
            + "&protocolName=Revamp%20Scheudle%20a%20TeleConsultation"
            + "&dependent=true"
            + "&fromWebView=ios"
            + "&ignoreLocationCheck=true"
            + "&disableCamera=true"
    }

    static func schedulesListUrl(config: AppConfig, profile: UserProfileData) -> String {
        "\(config.baseUrl)/\(config.folder)/rpm/#/webview/\(profile.clinicID)/\(profile.userID)/patient-schedule?fromWebView=ios"
    }
}
