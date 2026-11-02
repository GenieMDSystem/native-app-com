package com.example.webviewbrowserbridge

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Type 8 location. Answers the page with `window.onNativeLocation(jsonString)`.
 *
 * Granted: `{ success: true, latitude, longitude }`
 * Denied: `{ success: false, code: 1 }`
 * Unavailable: `{ success: false, code: 2 }`
 * Timeout: `{ success: false, code: 3 }`
 */
class NativeLocationHelper(
    private val activity: AppCompatActivity,
    private val onResult: (JSONObject) -> Unit,
) {
    companion object {
        private const val TAG = "WebViewBridge"
        const val CODE_PERMISSION_DENIED = 1
        const val CODE_UNAVAILABLE = 2
        const val CODE_TIMEOUT = 3
        private const val MAX_AGE_MS = 60_000L
        private val LOCATION_PERMISSIONS = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
    }

    private val locationManager =
        activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingHighAccuracy = false
    private var pendingTimeoutMs = 30_000L
    private var delivered = false
    private var timeoutRunnable: Runnable? = null
    private var listener: LocationListener? = null

    private val permissionLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val granted = results[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            results[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) {
            startUpdates(pendingHighAccuracy, pendingTimeoutMs)
        } else {
            deliverDenied()
        }
    }

    fun request(enableHighAccuracy: Boolean, timeoutMs: Long) {
        cancel()
        delivered = false
        pendingHighAccuracy = enableHighAccuracy
        pendingTimeoutMs = timeoutMs.coerceAtLeast(1_000L)

        if (hasLocationPermission()) {
            startUpdates(enableHighAccuracy, pendingTimeoutMs)
        } else {
            permissionLauncher.launch(LOCATION_PERMISSIONS)
        }
    }

    fun cancel() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
        listener?.let { locationManager.removeUpdates(it) }
        listener = null
    }

    @SuppressLint("MissingPermission")
    private fun startUpdates(enableHighAccuracy: Boolean, timeoutMs: Long) {
        if (!hasLocationPermission()) {
            deliverDenied()
            return
        }

        val provider = selectProvider(enableHighAccuracy)
        if (provider == null) {
            deliver(success = false, code = CODE_UNAVAILABLE, message = "Location provider unavailable")
            return
        }

        val last = lastKnown(enableHighAccuracy)
        if (last != null && System.currentTimeMillis() - last.time <= MAX_AGE_MS) {
            deliverSuccess(last)
            return
        }

        val locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                deliverSuccess(location)
            }
        }
        listener = locationListener

        try {
            locationManager.requestLocationUpdates(
                provider,
                0L,
                0f,
                locationListener,
                Looper.getMainLooper()
            )
        } catch (e: Exception) {
            Log.d(TAG, "Error requesting location updates", e)
            deliver(success = false, code = CODE_UNAVAILABLE, message = e.message)
            return
        }

        val timeout = Runnable {
            val fallback = lastKnown(enableHighAccuracy)
            if (fallback != null) {
                deliverSuccess(fallback)
            } else {
                deliver(success = false, code = CODE_TIMEOUT, message = "Location request timed out")
            }
        }
        timeoutRunnable = timeout
        mainHandler.postDelayed(timeout, timeoutMs)
    }

    @SuppressLint("MissingPermission")
    private fun lastKnown(enableHighAccuracy: Boolean): Location? {
        if (!hasLocationPermission()) {
            return null
        }
        val providers = mutableListOf<String>()
        if (enableHighAccuracy && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            providers.add(LocationManager.GPS_PROVIDER)
        }
        if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            providers.add(LocationManager.NETWORK_PROVIDER)
        }
        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            providers.add(LocationManager.GPS_PROVIDER)
        }
        return providers
            .distinct()
            .mapNotNull { runCatching { locationManager.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
    }

    private fun selectProvider(enableHighAccuracy: Boolean): String? {
        val fine = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        if (enableHighAccuracy && fine && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            return LocationManager.GPS_PROVIDER
        }
        if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            return LocationManager.NETWORK_PROVIDER
        }
        if (fine && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            return LocationManager.GPS_PROVIDER
        }
        return null
    }

    private fun deliverSuccess(location: Location) {
        deliver(
            success = true,
            latitude = location.latitude,
            longitude = location.longitude,
        )
    }

    private fun deliverDenied() {
        deliver(
            success = false,
            code = CODE_PERMISSION_DENIED,
            permissionDenied = true,
            message = "Location permission denied",
        )
    }

    private fun deliver(
        success: Boolean,
        code: Int? = null,
        permissionDenied: Boolean? = null,
        message: String? = null,
        latitude: Double? = null,
        longitude: Double? = null,
    ) {
        if (delivered) {
            return
        }
        delivered = true
        cancel()
        val payload = JSONObject().apply {
            put("success", success)
            if (code != null) put("code", code)
            if (permissionDenied != null) put("permissionDenied", permissionDenied)
            if (message != null) put("message", message)
            if (latitude != null) put("latitude", latitude)
            if (longitude != null) put("longitude", longitude)
        }
        Log.d(TAG, "onNativeLocation success=$success code=$code")
        onResult(payload)
    }

    private fun hasLocationPermission(): Boolean {
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
    }
}
