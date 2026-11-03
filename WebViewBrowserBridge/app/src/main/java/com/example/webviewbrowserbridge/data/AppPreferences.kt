package com.example.webviewbrowserbridge.data

import android.content.Context
import android.content.SharedPreferences
import com.example.webviewbrowserbridge.VisitDoctorFlags

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

    fun isLocalMode(): Boolean = prefs.getBoolean(KEY_LOCAL_MODE, false)

    fun setLocalMode(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LOCAL_MODE, enabled).apply()
    }

    fun getVisitDoctorFlags(): VisitDoctorFlags {
        return VisitDoctorFlags(
            dependent = prefs.getBoolean(KEY_FLAG_DEPENDENT, false),
            ignoreLocationCheck = prefs.getBoolean(KEY_FLAG_IGNORE_LOCATION, false),
        )
    }

    fun saveVisitDoctorFlags(flags: VisitDoctorFlags) {
        prefs.edit()
            .putBoolean(KEY_FLAG_DEPENDENT, flags.dependent)
            .putBoolean(KEY_FLAG_IGNORE_LOCATION, flags.ignoreLocationCheck)
            .apply()
    }

    fun isShrinkViewportOnKeyboard(): Boolean = prefs.getBoolean(KEY_SHRINK_VIEWPORT, false)

    fun setShrinkViewportOnKeyboard(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SHRINK_VIEWPORT, enabled).apply()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_NAME = "webview_bridge_cache"

        private const val KEY_SUBDOMAIN = "subdomain"
        private const val KEY_FOLDER = "folder"
        private const val KEY_LOCAL_MODE = "local_mode"
        private const val KEY_TOKEN = "token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_CLINIC_ID = "clinic_id"
        private const val KEY_LANGUAGE_ID = "language_id"
        private const val KEY_OEM_ID = "oem_id"
        private const val KEY_DISPLAY_NAME = "display_name"
        private const val KEY_FLAG_DEPENDENT = "flag_dependent"
        private const val KEY_FLAG_IGNORE_LOCATION = "flag_ignore_location"
        private const val KEY_SHRINK_VIEWPORT = "shrink_viewport_keyboard"
    }
}
