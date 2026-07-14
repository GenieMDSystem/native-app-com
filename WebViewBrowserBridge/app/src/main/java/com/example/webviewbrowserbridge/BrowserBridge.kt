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
 * Action types for native [BrowserBridge.callback] messages.
 *
 * JS sends JSON:
 *   NativeApp.callback(JSON.stringify({ type: 1, data: "https://example.com" }))
 *   NativeApp.callback(JSON.stringify({ type: 2, data: "Hello from WebView" }))
 */
enum class BridgeAction(val type: Int) {
    OPEN_LINK(1),
    SHOW_TOAST(2);

    companion object {
        fun from(type: Int): BridgeAction? = entries.find { it.type == type }
    }
}

/**
 * Payload shape from JavaScript:
 * `{ "type": number, "data": any }`
 */
data class BridgeCallbackMessage(
    val type: Int,
    val data: Any?
)

/**
 * JavaScript bridge exposed as [INTERFACE_NAME] ("NativeApp").
 *
 * Single entry point: [callback] with `{ type, data }`.
 */
class BrowserBridge(private val context: Context) {

    companion object {
        const val INTERFACE_NAME = "NativeApp"
        private const val TAG = "WebViewBridge"
    }

    /**
     * Native callback from WebView.
     *
     * @param json JSON string: `{ "type": number, "data": any }`
     */
    @JavascriptInterface
    fun callback(json: String) {
        val message = parseCallbackMessage(json) ?: return
        val action = BridgeAction.from(message.type)
        if (action == null) {
            Log.d(TAG, "Error: unknown callback type=${message.type} data=${message.data}")
            return
        }

        Log.d(TAG, "Native callback type=${message.type} ($action) data=${message.data}")

        when (action) {
            BridgeAction.OPEN_LINK -> openLink(message.data?.toString().orEmpty())
            BridgeAction.SHOW_TOAST -> showToastMessage(message.data?.toString().orEmpty())
        }
    }

    private fun parseCallbackMessage(json: String): BridgeCallbackMessage? {
        return try {
            val obj = JSONObject(json)
            if (!obj.has("type")) {
                Log.d(TAG, "Error: callback missing 'type': $json")
                return null
            }
            BridgeCallbackMessage(
                type = obj.getInt("type"),
                // "data" can be string, number, boolean, object, array, or null
                data = if (obj.isNull("data")) null else obj.get("data")
            )
        } catch (e: Exception) {
            Log.d(TAG, "Error: invalid callback JSON: $json", e)
            null
        }
    }

    private fun openLink(url: String) {
        Log.d(TAG, "Browser launch requested: $url")

        if (!isValidHttpUrl(url)) {
            Log.d(TAG, "Error: rejected invalid URL from OPEN_LINK: $url")
            return
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.d(TAG, "Browser launch success: $url")
        } catch (e: ActivityNotFoundException) {
            Log.d(TAG, "Error: no browser available for URL: $url", e)
        } catch (e: Exception) {
            Log.d(TAG, "Error: failed to launch browser for URL: $url", e)
        }
    }

    private fun showToastMessage(message: String) {
        Log.d(TAG, "SHOW_TOAST message: $message")
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun isValidHttpUrl(url: String): Boolean {
        if (url.isBlank()) return false
        return try {
            val uri = Uri.parse(url)
            val scheme = uri.scheme?.lowercase()
            (scheme == "http" || scheme == "https") && !uri.host.isNullOrBlank()
        } catch (e: Exception) {
            Log.d(TAG, "Error: URL parse failed: $url", e)
            false
        }
    }
}
