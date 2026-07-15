package com.example.webviewbrowserbridge.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Persists environment config and logged-in user session in app cache.
 */
class AppPreferences(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun hasConfig(): Boolean = prefs.contains(KEY_SUBDOMAIN) && prefs.contains(KEY_FOLDER)

    fun getConfig(): AppConfig? {
        val subdomain = prefs.getString(KEY_SUBDOMAIN, null) ?: return null
        val folder = prefs.getString(KEY_FOLDER, null) ?: return null
        return AppConfig(subdomain = subdomain, folder = folder)
    }

    fun saveConfig(subdomain: String, folder: String) {
        prefs.edit()
            .putString(KEY_SUBDOMAIN, subdomain.trim())
            .putString(KEY_FOLDER, folder.trim())
            .apply()
    }

    fun isLoggedIn(): Boolean =
        !prefs.getString(KEY_TOKEN, null).isNullOrBlank() &&
            !prefs.getString(KEY_USER_ID, null).isNullOrBlank()

    fun getSession(): UserSession? {
        val token = prefs.getString(KEY_TOKEN, null) ?: return null
        val userID = prefs.getString(KEY_USER_ID, null) ?: return null
        val clinicID = prefs.getString(KEY_CLINIC_ID, null) ?: return null
        val languageId = prefs.getInt(KEY_LANGUAGE_ID, -1)
        val oemID = prefs.getInt(KEY_OEM_ID, -1)
        val displayName = prefs.getString(KEY_DISPLAY_NAME, "") ?: ""

        if (languageId < 0 || oemID < 0) return null

        return UserSession(
            token = token,
            profile = UserProfileData(
                userID = userID,
                clinicID = clinicID,
                languageId = languageId,
                oemID = oemID,
                displayName = displayName
            )
        )
    }

    fun saveSession(token: String, profile: UserProfileData) {
        prefs.edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_USER_ID, profile.userID)
            .putString(KEY_CLINIC_ID, profile.clinicID)
            .putInt(KEY_LANGUAGE_ID, profile.languageId)
            .putInt(KEY_OEM_ID, profile.oemID)
            .putString(KEY_DISPLAY_NAME, profile.displayName)
            .apply()
    }

    /** Clears login token and profile; keeps environment config. */
    fun clearSession() {
        prefs.edit()
            .remove(KEY_TOKEN)
            .remove(KEY_USER_ID)
            .remove(KEY_CLINIC_ID)
            .remove(KEY_LANGUAGE_ID)
            .remove(KEY_OEM_ID)
            .remove(KEY_DISPLAY_NAME)
            .apply()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_NAME = "webview_bridge_cache"

        private const val KEY_SUBDOMAIN = "subdomain"
        private const val KEY_FOLDER = "folder"
        private const val KEY_TOKEN = "token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_CLINIC_ID = "clinic_id"
        private const val KEY_LANGUAGE_ID = "language_id"
        private const val KEY_OEM_ID = "oem_id"
        private const val KEY_DISPLAY_NAME = "display_name"
    }
}
