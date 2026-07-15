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

/**
 * Callback types from JavaScript → native.
 *
 * type 1 WAITING_ROOM:
 *   { type: 1, data: { url, success, openInBrowser } }
 *
 * type 2 SCHEDULE / CLOSE:
 *   { type: 2, data: { success: true } }  — closes WebView, returns home
 *   { type: 2, data: { close: true } }    — closes WebView, returns home
 *
 * type 3 OPEN_SCHEDULE_LINK:
 *   { type: 3, data: { url, success, openInBrowser } }
 */
enum class BridgeAction(val type: Int) {
    WAITING_ROOM(1),
    SCHEDULE(2),
    OPEN_SCHEDULE_LINK(3);

    companion object {
        fun from(type: Int): BridgeAction? = entries.find { it.type == type }
    }
}

data class UrlBridgeData(
    val url: String,
    val success: Boolean,
    val openInBrowser: Boolean
)

data class ScheduleBridgeData(
    val success: Boolean,
    val close: Boolean
) {
    /** Close WebView and return to home when either flag is true. */
    val shouldCloseWebView: Boolean get() = success || close
}

interface BridgeCallbackHost {
    fun loadUrlInWebView(url: String)
    fun finishWithResult()
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
                BridgeAction.WAITING_ROOM -> handleUrlAction(action, parseUrlData(data))
                BridgeAction.SCHEDULE -> handleSchedule(parseScheduleData(data))
                BridgeAction.OPEN_SCHEDULE_LINK -> handleUrlAction(action, parseUrlData(data))
            }
        } catch (e: Exception) {
            Log.d(TAG, "Error: invalid callback JSON: $json", e)
            toast("Invalid callback JSON")
        }
    }

    private fun handleUrlAction(action: BridgeAction, payload: UrlBridgeData?) {
        if (payload == null) {
            Log.d(TAG, "Error: invalid url payload for $action")
            toast("Invalid ${action.name.lowercase()} payload")
            return
        }

        Log.d(
            TAG,
            "$action success=${payload.success} openInBrowser=${payload.openInBrowser} url=${payload.url}"
        )

        if (!payload.success) {
            toast("${actionLabel(action)} failed")
            return
        }

        if (!isValidHttpUrl(payload.url)) {
            Log.d(TAG, "Error: rejected invalid URL: ${payload.url}")
            toast("Invalid URL")
            return
        }

        mainHandler.post {
            if (payload.openInBrowser) {
                // Open external browser, then return to the native home screen
                openInBrowser(payload.url)
                Log.d(TAG, "$action opened browser — navigating back to main screen")
                host.finishWithResult()
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

    private fun parseUrlData(data: JSONObject): UrlBridgeData {
        return UrlBridgeData(
            url = data.optString("url", ""),
            success = data.optBoolean("success", false),
            openInBrowser = data.optBoolean("openInBrowser", false)
        )
    }

    private fun parseScheduleData(data: JSONObject): ScheduleBridgeData {
        return ScheduleBridgeData(
            success = data.optBoolean("success", false),
            close = data.optBoolean("close", false)
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
    }

    private fun toast(message: String) {
        mainHandler.post {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }
}
