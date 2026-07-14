package com.example.webviewbrowserbridge

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.webkit.JavascriptInterface
import android.widget.Toast

/**
 * JavaScript bridge exposed to the WebView as [INTERFACE_NAME].
 *
 * Web pages call methods such as:
 *   NativeApp.openInBrowser(url)
 *   NativeApp.showToast(message)
 *
 * Every public method annotated with [JavascriptInterface] is callable from JS.
 * Methods without that annotation are not exposed (API 17+).
 */
class BrowserBridge(private val context: Context) {

    companion object {
        const val INTERFACE_NAME = "NativeApp"
        private const val TAG = "WebViewBridge"
    }

    /**
     * Opens [url] in the device's default browser via ACTION_VIEW.
     * Invalid or unsupported URLs are ignored after logging an error.
     */
    @JavascriptInterface
    fun openInBrowser(url: String) {
        Log.d(TAG, "Browser launch requested: $url")

        if (!isValidHttpUrl(url)) {
            Log.d(TAG, "Error: rejected invalid URL from openInBrowser: $url")
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

    /**
     * Shows a short Android Toast with the given [message].
     */
    @JavascriptInterface
    fun showToast(message: String) {
        Log.d(TAG, "showToast called with message: $message")
        // Toast must run on the main thread; post via main looper.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            Toast.makeText(context.applicationContext, message, Toast.LENGTH_SHORT).show()
        }
    }

    /**
     * Accepts only http/https URLs with a non-blank host.
     */
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
