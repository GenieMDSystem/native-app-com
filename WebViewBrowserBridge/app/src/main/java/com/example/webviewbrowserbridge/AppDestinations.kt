package com.example.webviewbrowserbridge

import com.example.webviewbrowserbridge.data.AppConfig
import com.example.webviewbrowserbridge.data.UserProfile

/**
 * Builds WebView URLs from saved environment + logged-in profile.
 */
object AppDestinations {

  /**
   * Visit Doctor — assessment consent flow.
   *
   * https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
   *   ?patientLanguageID={languageId}&patientOEMID={oemID}&ignoreLocalStorage=true&dependent=true&fromWebView=android
   */
  fun visitDoctorUrl(config: AppConfig, profile: UserProfile): String {
    return buildString {
      append(config.baseUrl)
      append("/")
      append(config.folder)
      append("/assessment/#/protocol/")
      append(profile.clinicID)
      append("/consent/")
      append(profile.userID)
      append("?patientLanguageID=")
      append(profile.languageId)
      append("&patientOEMID=")
      append(profile.oemID)
      append("&protocolName=Revamp%20TeleConsultation&dependent=true&fromWebView=android")
    }
  }

  /** Schedule visit — RPM shell (update path when your web team provides the exact route). */
  fun scheduleVisitUrl(config: AppConfig, profile: UserProfile): String {
    return buildString {
      append(config.baseUrl)
      append("/")
      append(config.folder)
      append("/assessment/#/protocol/")
      append(profile.clinicID)
      append("/consent/")
      append(profile.userID)
      append("?patientLanguageID=")
      append(profile.languageId)
      append("&patientOEMID=")
      append(profile.oemID)
      append("&protocolName=Revamp%20Scheudle%20a%20TeleConsultation&dependent=true&fromWebView=android")
    }
  }

  /** Schedules list — RPM appointments (update path when your web team provides the exact route). */
  fun schedulesListUrl(config: AppConfig, profile: UserProfile): String {
    return "${config.baseUrl}/${config.folder}/rpm/#/webview/${profile.clinicID}/${profile.userID}/patient-schedule?fromWebView=android"
  }
}
