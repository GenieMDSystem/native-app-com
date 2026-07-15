package com.example.webviewbrowserbridge.network

import com.example.webviewbrowserbridge.data.AppConfig
import com.example.webviewbrowserbridge.data.LoginResult
import com.example.webviewbrowserbridge.data.UserProfileData
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class GenieMdApi {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    /**
     * POST /ivisit.ComV5.00/resources/Email/ValidateLogin/
     */
    fun validateLogin(config: AppConfig, username: String, password: String): LoginResult {
        val url = "${config.baseUrl}/ivisit.ComV5.00/resources/Email/ValidateLogin/"
        val body = JSONObject()
            .put("username", username)
            .put("password", password)
            .toString()
            .toRequestBody(jsonMediaType)

        val request = Request.Builder()
            .url(url)
            .post(body)
            .header("Accept", "application/json, text/plain, */*")
            .header("Content-Type", "application/json")
            .header("Referer", config.refererUrl)
            .build()

        client.newCall(request).execute().use { response ->
            val responseBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ApiException("Login failed (${response.code}): $responseBody")
            }
            val json = JSONObject(responseBody)
            val token = json.optString("token", "")
            if (token.isBlank()) {
                throw ApiException("Login response missing token")
            }
            return LoginResult(
                token = token,
                registrationComplete = json.optString("RegistrationComplete", "false") == "true",
                active = json.optBoolean("active", false)
            )
        }
    }

    /**
     * GET /ivisit.ComV5.00/resources/Profile/{token}
     */
    fun fetchProfile(config: AppConfig, token: String): UserProfileData {
        val url = "${config.baseUrl}/ivisit.ComV5.00/resources/Profile/$token"
        val request = Request.Builder()
            .url(url)
            .get()
            .header("Accept", "application/json, text/plain, */*")
            .header("Referer", config.refererUrl)
            .build()

        client.newCall(request).execute().use { response ->
            val responseBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw ApiException("Profile failed (${response.code}): $responseBody")
            }
            return parseProfile(JSONObject(responseBody))
        }
    }

    private fun parseProfile(json: JSONObject): UserProfileData {
        val userID = json.optString("userID", "")
        val clinicID = json.optString("clinicID", "")
        val languageId = json.optInt("languageId", -1)
        val oemID = json.optInt("oemID", -1)

        if (userID.isBlank() || clinicID.isBlank() || languageId < 0 || oemID < 0) {
            throw ApiException("Profile response missing required fields")
        }

        val displayName = when {
            json.optString("screenName").isNotBlank() -> json.optString("screenName")
            json.optString("firstName").isNotBlank() -> {
                "${json.optString("firstName")} ${json.optString("lastName")}".trim()
            }
            else -> json.optString("userName", userID)
        }

        return UserProfileData(
            userID = userID,
            clinicID = clinicID,
            languageId = languageId,
            oemID = oemID,
            displayName = displayName
        )
    }
}

class ApiException(message: String) : Exception(message)
