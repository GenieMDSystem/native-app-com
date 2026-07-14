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

/**
 * Action types accepted by [BrowserBridge.invoke] from JavaScript.
 *
 * JS calls:
 *   NativeApp.invoke(1, "https://example.com")  // OPEN_LINK
 *   NativeApp.invoke(2, "Hello from WebView")    // SHOW_TOAST
 */
enum class BridgeAction(val type: Int) {
    /** Open [payload] in the device browser. */
    OPEN_LINK(1),

    /** Show [payload] as an Android Toast. */
    SHOW_TOAST(2);

    companion object {
        fun from(type: Int): BridgeAction? = entries.find { it.type == type }
    }
}

/**
 * JavaScript bridge exposed to the WebView as [INTERFACE_NAME].
 *
 * Prefer the single entry point [invoke] with a [BridgeAction] type code.
 * Methods without [@JavascriptInterface] are not exposed (API 17+).
 */
class BrowserBridge(private val context: Context) {

    companion object {
        const val INTERFACE_NAME = "NativeApp"
        private const val TAG = "WebViewBridge"
    }

    /**
     * Unified bridge entry point.
     *
     * @param actionType [BridgeAction.type] — `1` open link, `2` show toast
     * @param payload URL for [BridgeAction.OPEN_LINK], message for [BridgeAction.SHOW_TOAST]
     */
    @JavascriptInterface
    fun invoke(actionType: Int, payload: String) {
        val action = BridgeAction.from(actionType)
        if (action == null) {
            Log.d(TAG, "Error: unknown bridge actionType=$actionType payload=$payload")
            return
        }

        Log.d(TAG, "Bridge invoke action=$action ($actionType) payload=$payload")

        when (action) {
            BridgeAction.OPEN_LINK -> openLink(payload)
            BridgeAction.SHOW_TOAST -> showToastMessage(payload)
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
        // Toast must run on the main thread; JavascriptInterface runs off the UI thread.
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    /** Accepts only http/https URLs with a non-blank host. */
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
