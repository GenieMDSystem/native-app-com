import Foundation

struct VisitDoctorFlags: Equatable {
    var dependent = false
    var ignoreLocationCheck = false
    var disableCamera = false
    var forWR = false
}

/// Builds WebView URLs from saved environment + logged-in profile.
/// Uses `fromWebView=ios` (Android uses `android`).
enum AppDestinations {
    private static let platform = "ios"

    static let localAssessmentBase = "http://localhost:4201"

    /// Localhost hosts are debug-only; release/prod always uses live URLs.
    static var isLocalHostEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func useLocalHost(_ requested: Bool) -> Bool {
        requested && isLocalHostEnabled
    }

    private static func assessmentBase(config: AppConfig, useLocal: Bool) -> String {
        useLocalHost(useLocal) ? localAssessmentBase : "\(config.baseUrl)/\(config.folder)/assessment"
    }

    /// Visit Doctor
    /// live:  https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/...
    /// local: http://localhost:4201/#/protocol/...
    /// protocolName is never added. Optional flags are appended only when selected.
    static func visitDoctorUrl(
        config: AppConfig,
        profile: UserProfileData,
        useLocal: Bool = false,
        flags: VisitDoctorFlags = VisitDoctorFlags()
    ) -> String {
        var url = "\(assessmentBase(config: config, useLocal: useLocal))/#/protocol/"
        url += "\(profile.clinicID)/consent/\(profile.userID)"
        url += "?patientLanguageID=\(profile.languageId)"
        url += "&patientOEMID=\(profile.oemID)"
        url += "&fromWebView=\(platform)"
        url += "&openPickerInNative=true"
        if flags.dependent { url += "&dependent=true" }
        if flags.ignoreLocationCheck { url += "&ignoreLocationCheck=true" }
        if flags.disableCamera { url += "&disableCamera=true" }
        if flags.forWR { url += "&forWR=true" }
        return url
    }
}
