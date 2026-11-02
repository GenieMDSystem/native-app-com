package com.example.webviewbrowserbridge

import com.example.webviewbrowserbridge.data.AppConfig
import com.example.webviewbrowserbridge.data.UserProfile

data class VisitDoctorFlags(
    val dependent: Boolean = false,
    val ignoreLocationCheck: Boolean = false,
    val disableCamera: Boolean = false,
    val forWR: Boolean = false,
)

/**
 * Builds WebView URLs from saved environment + logged-in profile.
 */
object AppDestinations {

    const val LOCAL_ASSESSMENT_BASE = "http://localhost:4201"

    /** Localhost hosts are debug-only; release/prod always uses live URLs. */
    val isLocalHostEnabled: Boolean get() = BuildConfig.ENABLE_LOCAL_HOST

    private fun useLocalHost(requested: Boolean): Boolean = requested && isLocalHostEnabled

    private fun assessmentBase(config: AppConfig, useLocal: Boolean): String {
        return if (useLocalHost(useLocal)) {
            LOCAL_ASSESSMENT_BASE
        } else {
            "${config.baseUrl}/${config.folder}/assessment"
        }
    }

    /**
     * Visit Doctor url.
     *
     * live:  https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/...
     * local: http://localhost:4201/#/protocol/...
     *
     * Always includes fromWebView + openPickerInNative.
     * Optional flags are appended only when selected in the UI.
     * protocolName is never added.
     */
    fun visitDoctorUrl(
        config: AppConfig,
        profile: UserProfile,
        useLocal: Boolean = false,
        flags: VisitDoctorFlags = VisitDoctorFlags(),
    ): String {
        return buildString {
            append(assessmentBase(config, useLocal))
            append("/#/protocol/")
            append(profile.clinicID)
            append("/consent/")
            append(profile.userID)
            append("?patientLanguageID=")
            append(profile.languageId)
            append("&patientOEMID=")
            append(profile.oemID)
            append("&fromWebView=android")
            append("&openPickerInNative=true")
            if (flags.dependent) append("&dependent=true")
            if (flags.ignoreLocationCheck) append("&ignoreLocationCheck=true")
            if (flags.disableCamera) append("&disableCamera=true")
            if (flags.forWR) append("&forWR=true")
        }
    }
}
