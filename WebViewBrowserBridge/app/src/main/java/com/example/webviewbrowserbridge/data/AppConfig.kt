package com.example.webviewbrowserbridge.data

/**
 * Server environment saved on first launch.
 *
 * Full domain: https://{subdomain}.geniemd.net/{folder}/...
 */
data class AppConfig(
    val subdomain: String,
    val folder: String
) {
    val baseUrl: String get() = "https://$subdomain.geniemd.net"

    /** Display / path base, e.g. https://mhc.geniemd.net/apps2 */
    val environmentUrl: String get() = "$baseUrl/$folder"

    val refererUrl: String get() = "$baseUrl/$folder/rpm/"
}
