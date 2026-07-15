package com.example.webviewbrowserbridge.data

/**
 * Profile fields used by the native app and WebView URL builder.
 */
interface UserProfile {
    val userID: String
    val clinicID: String
    val languageId: Int
    val oemID: Int
    val displayName: String
}

data class UserProfileData(
    override val userID: String,
    override val clinicID: String,
    override val languageId: Int,
    override val oemID: Int,
    override val displayName: String
) : UserProfile

data class UserSession(
    val token: String,
    val profile: UserProfileData
)

data class LoginResult(
    val token: String,
    val registrationComplete: Boolean,
    val active: Boolean
)
