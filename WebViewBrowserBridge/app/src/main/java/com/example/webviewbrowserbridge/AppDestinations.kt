package com.example.webviewbrowserbridge

/**
 * Configurable entry URLs for each home-screen destination.
 * Point these at your hosted pages when ready.
 */
object AppDestinations {
    /**
     * Visit Doctor Now → Waiting Room WebView.
     * Swap to your hosted / GenieMD waiting-room URL when ready, e.g.:
     * "https://dev.geniemd.net/neurofinity/assessment/#/protocol/..."
     */
    const val VISIT_DOCTOR_URL =
        // "file:///android_asset/waiting_room.html"
        "https://dev.geniemd.net/neurofinity/assessment/#/protocol/1000254/consent?patientLanguageID=1&patientOEMID=100&ignoreLocalStorage=true&dependent=true&fromWebView=android";

    /** Schedule Visit Now → Schedule flow WebView */
    const val SCHEDULE_VISIT_URL =
        // "file:///android_asset/schedule.html"
        "https://dev.geniemd.net/neurofinity/assessment/#/protocol/1000254/consent?patientLanguageID=1&patientOEMID=100&ignoreLocalStorage=true&dependent=true&fromWebView=android";

    /** Schedules List → list WebView */
    const val SCHEDULES_LIST_URL =
        // "file:///android_asset/schedules_list.html"
        "https://dev.geniemd.net/neurofinity/assessment/#/protocol/1000254/consent?patientLanguageID=1&patientOEMID=100&ignoreLocalStorage=true&dependent=true&fromWebView=android";
}
