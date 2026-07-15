package com.example.webviewbrowserbridge

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

/**
 * Bridges Android runtime permissions to WebView [PermissionRequest] and geolocation prompts.
 */
class WebViewPermissionHelper(private val activity: AppCompatActivity) {

    companion object {
        private const val TAG = "WebViewBridge"

        private val LOCATION_PERMISSIONS = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    }

    private var pendingWebRequest: PermissionRequest? = null
    private var pendingGeoOrigin: String? = null
    private var pendingGeoCallback: GeolocationPermissions.Callback? = null

    private val permissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val allGranted = results.values.all { it }
        Log.d(TAG, "Runtime permission result: $results (allGranted=$allGranted)")

        pendingWebRequest?.let { request ->
            if (allGranted) {
                request.grant(request.resources)
                Log.d(TAG, "Granted WebView resources: ${request.resources.joinToString()}")
            } else {
                request.deny()
                Log.d(TAG, "Denied WebView permission request")
            }
            pendingWebRequest = null
        }

        pendingGeoCallback?.let { callback ->
            callback.invoke(pendingGeoOrigin, allGranted, false)
            Log.d(TAG, "Geolocation callback origin=$pendingGeoOrigin granted=$allGranted")
            pendingGeoCallback = null
            pendingGeoOrigin = null
        }
    }

    /**
     * Handles getUserMedia() camera / microphone requests from the page.
     */
    fun onWebPermissionRequest(request: PermissionRequest) {
        val androidPermissions = mapWebResourcesToAndroidPermissions(request.resources)
        Log.d(TAG, "WebView permission request resources=${request.resources.joinToString()}")

        if (androidPermissions.isEmpty()) {
            request.grant(request.resources)
            return
        }

        if (hasPermissions(androidPermissions)) {
            request.grant(request.resources)
            Log.d(TAG, "Granted WebView resources (already had runtime permissions)")
            return
        }

        pendingWebRequest = request
        permissionLauncher.launch(androidPermissions)
    }

    /**
     * Handles navigator.geolocation requests from the page.
     */
    fun onGeolocationRequest(origin: String?, callback: GeolocationPermissions.Callback) {
        Log.d(TAG, "Geolocation permission request from origin=$origin")

        if (hasPermissions(LOCATION_PERMISSIONS)) {
            callback.invoke(origin, true, false)
            Log.d(TAG, "Granted geolocation (already had runtime permissions)")
            return
        }

        pendingGeoOrigin = origin
        pendingGeoCallback = callback
        permissionLauncher.launch(LOCATION_PERMISSIONS)
    }

    /**
     * Optionally pre-request common WebView permissions when the screen opens.
     */
    fun requestCommonPermissionsIfNeeded() {
        val common = arrayOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ).filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (common.isNotEmpty()) {
            Log.d(TAG, "Pre-requesting WebView permissions: ${common.joinToString()}")
            permissionLauncher.launch(common)
        }
    }

    private fun mapWebResourcesToAndroidPermissions(resources: Array<String>): Array<String> {
        val permissions = mutableSetOf<String>()
        for (resource in resources) {
            when (resource) {
                PermissionRequest.RESOURCE_VIDEO_CAPTURE ->
                    permissions.add(Manifest.permission.CAMERA)
                PermissionRequest.RESOURCE_AUDIO_CAPTURE ->
                    permissions.add(Manifest.permission.RECORD_AUDIO)
            }
        }
        return permissions.toTypedArray()
    }

    private fun hasPermissions(permissions: Array<String>): Boolean {
        return permissions.all {
            ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }
    }
}
