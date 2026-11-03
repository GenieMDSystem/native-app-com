package com.example.webviewbrowserbridge

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import android.widget.Toast
import org.json.JSONObject

// Callback types from JavaScript -> native. Must match PTX bridge-action.constant.ts.
// type 1 WAITING_ROOM: { type: 1, data: { url, success, openInBrowser } }
// type 2 SCHEDULE / CLOSE: { type: 2, data: { success: true } } or { close: true }
// type 3 OPEN_SCHEDULE_LINK: { type: 3, data: { url, success, openInBrowser } }
// type 4 OPEN_NATIVE_IMAGE_PICKER: { type: 4, data: { accept, source, multiple } }
//   Native answers with window.onNativeImagePicked(json).
// type 5 OPEN_NATIVE_VIDEO_PICKER: { type: 5, data: { accept: 'video/*', source, multiple } }
//   Native answers with window.onNativeVideoPicked(json).
// type 6 OPEN_NATIVE_FILE_PICKER: { type: 6, data: { accept: '*/*', source: 'files', multiple } }
//   Native answers with window.onNativeFilePicked(json).
// type 7 OPEN_EXTERNAL_LINK: { type: 7, data: { url, success, openInBrowser, target } }
// type 8 GET_NATIVE_LOCATION: { type: 8, data: { enableHighAccuracy, timeout } }
//   Native answers with window.onNativeLocation(json).
enum class BridgeAction(val type: Int) {
    WAITING_ROOM(1),
    SCHEDULE(2),
    OPEN_SCHEDULE_LINK(3),
    OPEN_NATIVE_IMAGE_PICKER(4),
    OPEN_NATIVE_VIDEO_PICKER(5),
    OPEN_NATIVE_FILE_PICKER(6),
    OPEN_EXTERNAL_LINK(7),
    GET_NATIVE_LOCATION(8);

    companion object {
        fun from(type: Int): BridgeAction? = entries.find { it.type == type }
    }
}

data class UrlBridgeData(
    val url: String,
    val success: Boolean,
    val openInBrowser: Boolean,
    val target: String = "_blank",
)

data class ScheduleBridgeData(
    val success: Boolean,
    val close: Boolean
) {
    /** Close WebView and return to home when either flag is true. */
    val shouldCloseWebView: Boolean get() = success || close
}

data class NativeLocationRequest(
    val enableHighAccuracy: Boolean,
    val timeoutMs: Long,
)

interface BridgeCallbackHost {
    fun loadUrlInWebView(url: String)
    fun finishWithResult()
    fun openNativeImagePicker(multiple: Boolean)
    fun openNativeVideoPicker()
    fun openNativeFilePicker()
    fun getNativeLocation(enableHighAccuracy: Boolean, timeoutMs: Long)
}

/**
 * JavaScript bridge exposed as [INTERFACE_NAME] ("NativeApp").
 *
 *   NativeApp.callback(JSON.stringify({ type, data }))
 */
class BrowserBridge(
    private val context: Context,
    private val host: BridgeCallbackHost
) {

    companion object {
        const val INTERFACE_NAME = "NativeApp"
        private const val TAG = "WebViewBridge"
        private const val DEFAULT_LOCATION_TIMEOUT_MS = 30_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun callback(json: String) {
        Log.d(TAG, "Native callback received: $json")
        try {
            val root = JSONObject(json)
            val type = root.getInt("type")
            val data = root.optJSONObject("data")
            val action = BridgeAction.from(type)

            if (action == null) {
                Log.d(TAG, "Error: unknown callback type=$type")
                toast("Unknown bridge action: $type")
                return
            }
            if (data == null) {
                Log.d(TAG, "Error: missing data object for type=$type")
                toast("Invalid bridge payload")
                return
            }

            when (action) {
                BridgeAction.WAITING_ROOM -> handleUrlAction(action, parseUrlData(data), closeAfterBrowser = true)
                BridgeAction.SCHEDULE -> handleSchedule(parseScheduleData(data))
                BridgeAction.OPEN_SCHEDULE_LINK -> handleUrlAction(action, parseUrlData(data), closeAfterBrowser = true)
                BridgeAction.OPEN_NATIVE_IMAGE_PICKER -> {
                    val multiple = data.optBoolean("multiple", false)
                    Log.d(
                        TAG,
                        "OPEN_NATIVE_IMAGE_PICKER accept=${data.optString("accept")} source=${data.optString("source")} multiple=$multiple"
                    )
                    mainHandler.post { host.openNativeImagePicker(multiple) }
                }
                BridgeAction.OPEN_NATIVE_VIDEO_PICKER -> {
                    Log.d(
                        TAG,
                        "OPEN_NATIVE_VIDEO_PICKER accept=${data.optString("accept")} source=${data.optString("source")}"
                    )
                    mainHandler.post { host.openNativeVideoPicker() }
                }
                BridgeAction.OPEN_NATIVE_FILE_PICKER -> {
                    Log.d(
                        TAG,
                        "OPEN_NATIVE_FILE_PICKER accept=${data.optString("accept")} source=${data.optString("source")}"
                    )
                    mainHandler.post { host.openNativeFilePicker() }
                }
                BridgeAction.OPEN_EXTERNAL_LINK -> handleUrlAction(
                    action,
                    parseUrlData(data),
                    closeAfterBrowser = false
                )
                BridgeAction.GET_NATIVE_LOCATION -> {
                    val request = parseLocationRequest(data)
                    Log.d(
                        TAG,
                        "GET_NATIVE_LOCATION enableHighAccuracy=${request.enableHighAccuracy} timeout=${request.timeoutMs}"
                    )
                    mainHandler.post {
                        host.getNativeLocation(request.enableHighAccuracy, request.timeoutMs)
                    }
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Error: invalid callback JSON: $json", e)
            toast("Invalid callback JSON")
        }
    }

    private fun handleUrlAction(
        action: BridgeAction,
        payload: UrlBridgeData?,
        closeAfterBrowser: Boolean
    ) {
        if (payload == null) {
            Log.d(TAG, "Error: invalid url payload for $action")
            toast("Invalid ${action.name.lowercase()} payload")
            return
        }

        logReceivedUrl(action, payload)

        if (!payload.success) {
            toast("${actionLabel(action)} failed")
            return
        }

        if (!isValidHttpUrl(payload.url)) {
            Log.d(TAG, "Error: rejected invalid URL: ${payload.url}")
            toast("Invalid URL")
            return
        }

        val openInBrowser = payload.openInBrowser || payload.target != "_self"

        mainHandler.post {
            if (openInBrowser) {
                openInBrowser(payload.url)
                if (closeAfterBrowser) {
                    Log.d(TAG, "$action opened browser — navigating back to main screen")
                    host.finishWithResult()
                }
            } else {
                host.loadUrlInWebView(payload.url)
            }
        }
    }

    private fun handleSchedule(payload: ScheduleBridgeData?) {
        if (payload == null) {
            Log.d(TAG, "Error: invalid schedule payload")
            return
        }

        Log.d(
            TAG,
            "SCHEDULE success=${payload.success} close=${payload.close} shouldClose=${payload.shouldCloseWebView}"
        )

        mainHandler.post {
            if (payload.shouldCloseWebView) {
                host.finishWithResult()
            }
        }
    }

    private fun logReceivedUrl(action: BridgeAction, payload: UrlBridgeData) {
        val label = when (action) {
            BridgeAction.WAITING_ROOM -> "WAITING_ROOM callback (type 1)"
            BridgeAction.OPEN_SCHEDULE_LINK -> "SCHEDULE_LINK callback (type 3)"
            BridgeAction.OPEN_EXTERNAL_LINK -> "OPEN_EXTERNAL_LINK callback (type 7)"
            else -> "${action.name} callback"
        }
        Log.i(TAG, "========== $label ==========")
        Log.i(TAG, "url=${payload.url}")
        Log.i(TAG, "success=${payload.success} openInBrowser=${payload.openInBrowser} target=${payload.target}")
        Log.i(TAG, "==========================================")
    }

    private fun parseUrlData(data: JSONObject): UrlBridgeData {
        val target = data.optString("target", "_blank").ifBlank { "_blank" }
        val openInBrowser = if (data.has("openInBrowser")) {
            data.optBoolean("openInBrowser", false)
        } else {
            target != "_self"
        }
        return UrlBridgeData(
            url = data.optString("url", ""),
            success = data.optBoolean("success", false),
            openInBrowser = openInBrowser,
            target = target,
        )
    }

    private fun parseScheduleData(data: JSONObject): ScheduleBridgeData {
        return ScheduleBridgeData(
            success = data.optBoolean("success", false),
            close = data.optBoolean("close", false)
        )
    }

    private fun parseLocationRequest(data: JSONObject): NativeLocationRequest {
        val timeout = data.optLong("timeout", DEFAULT_LOCATION_TIMEOUT_MS)
        return NativeLocationRequest(
            enableHighAccuracy = data.optBoolean("enableHighAccuracy", false),
            timeoutMs = if (timeout > 0) timeout else DEFAULT_LOCATION_TIMEOUT_MS,
        )
    }

    private fun openInBrowser(url: String) {
        Log.d(TAG, "Browser launch requested: $url")
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.d(TAG, "Browser launch success: $url")
        } catch (e: ActivityNotFoundException) {
            Log.d(TAG, "Error: no browser available for URL: $url", e)
            toast("No browser available")
        } catch (e: Exception) {
            Log.d(TAG, "Error: failed to launch browser for URL: $url", e)
            toast("Failed to open browser")
        }
    }

    private fun isValidHttpUrl(url: String): Boolean {
        if (url.isBlank()) return false
        return try {
            val uri = Uri.parse(url)
            val scheme = uri.scheme?.lowercase()
            (scheme == "http" || scheme == "https") && !uri.host.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun actionLabel(action: BridgeAction): String = when (action) {
        BridgeAction.WAITING_ROOM -> "Waiting room"
        BridgeAction.SCHEDULE -> "Schedule"
        BridgeAction.OPEN_SCHEDULE_LINK -> "Schedule link"
        BridgeAction.OPEN_NATIVE_IMAGE_PICKER -> "Photo library"
        BridgeAction.OPEN_NATIVE_VIDEO_PICKER -> "Video picker"
        BridgeAction.OPEN_NATIVE_FILE_PICKER -> "File picker"
        BridgeAction.OPEN_EXTERNAL_LINK -> "Open link"
        BridgeAction.GET_NATIVE_LOCATION -> "Location"
    }

    private fun toast(message: String) {
        mainHandler.post {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }
}
