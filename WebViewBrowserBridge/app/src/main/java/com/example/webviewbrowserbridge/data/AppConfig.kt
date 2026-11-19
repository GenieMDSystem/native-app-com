package com.example.webviewbrowserbridge.data

/**
 * Server environment saved on first launch.
 *
 * Full domain: https://{subdomain}.geniemd.net/{folder}/...
 *
 * [folder] is required. [folder2] is optional — when set, Home shows a
 * Folder1 ⇄ Folder2 switch (same pattern as Live ⇄ Local).
 */
data class AppConfig(
    val subdomain: String,
    val folder: String,
    val folder2: String? = null
) {
    val baseUrl: String get() = "https://$subdomain.geniemd.net"

    /** True when a secondary folder was saved. */
    val hasFolder2: Boolean get() = !folder2.isNullOrBlank()

    /** Active folder based on the Home folder switch. */
    fun activeFolder(useFolder2: Boolean): String =
        if (useFolder2 && hasFolder2) folder2!!.trim() else folder

    /** Config copy with [folder] set to the currently selected folder. */
    fun withActiveFolder(useFolder2: Boolean): AppConfig =
        copy(folder = activeFolder(useFolder2))

    /** Display / path base for the selected folder, e.g. https://mhc.geniemd.net/apps1 */
    fun environmentUrl(useFolder2: Boolean = false): String =
        "$baseUrl/${activeFolder(useFolder2)}"

    /** Legacy single-folder display (primary). */
    val environmentUrl: String get() = environmentUrl(useFolder2 = false)

    val refererUrl: String get() = "$baseUrl/$folder/rpm/"
}
