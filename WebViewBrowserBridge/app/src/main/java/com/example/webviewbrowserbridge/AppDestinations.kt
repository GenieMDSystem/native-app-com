package com.example.webviewbrowserbridge

import com.example.webviewbrowserbridge.data.AppConfig
import com.example.webviewbrowserbridge.data.UserProfile

/**
 * Builds WebView URLs from saved environment + logged-in profile.
 */
object AppDestinations {

    const val LOCAL_ASSESSMENT_BASE = "http://localhost:4201"
    const val LOCAL_RPM_BASE = "http://localhost:4200/rpm"

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

    private fun rpmBase(config: AppConfig, useLocal: Boolean): String {
        return if (useLocalHost(useLocal)) {
            LOCAL_RPM_BASE
        } else {
            "${config.baseUrl}/${config.folder}/rpm"
        }
    }

    /**
     * waiting room url.
     *
     * live:  https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/...
     * local: http://localhost:4201/#/protocol/...
     */
    fun visitDoctorUrl(config: AppConfig, profile: UserProfile, useLocal: Boolean = false): String {
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
            append("&protocolName=Revamp%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true&forWR=true")
        }
    }

    /** schedule a teleconsultation url. */
    fun scheduleVisitUrl(config: AppConfig, profile: UserProfile, useLocal: Boolean = false): String {
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
            append("&protocolName=Revamp%20Scheudle%20a%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true")
        }
    }

    /**
     * schedules list url.
     *
     * live:  https://{subdomain}.geniemd.net/{folder}/rpm/#/webview/...
     * local: http://localhost:4200/rpm/#/webview/...
     */
    fun schedulesListUrl(config: AppConfig, profile: UserProfile, useLocal: Boolean = false): String {
        return "${rpmBase(config, useLocal)}/#/webview/${profile.clinicID}/${profile.userID}/patient-schedule?fromWebView=android"
    }
}
