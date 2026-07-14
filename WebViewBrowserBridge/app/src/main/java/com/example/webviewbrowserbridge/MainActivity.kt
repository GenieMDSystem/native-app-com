package com.example.webviewbrowserbridge

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Hosts a full-screen WebView with a [BrowserBridge] JavaScript interface
 * exposed as [BrowserBridge.INTERFACE_NAME] ("NativeApp").
 *
 * Change [START_URL] to load any page that can call the native bridge.
 */
class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "WebViewBridge"

        /**
         * Configurable start URL.
         *
         * Options:
         * - Bundled demo:  file:///android_asset/sample_bridge.html
         * - Remote page:   https://example.com  (or your hosted sample HTML)
         *
         * The bundled asset ships the sample bridge UI so the app works offline
         * without hosting changes. Point this at your hosted page when ready.
         */
        // private const val START_URL = "file:///android_asset/sample_bridge.html"
        private const val START_URL = "https://dev.geniemd.net/neurofinity/assessment/#/protocol/1000254/consent?patientLanguageID=1&patientOEMID=100&ignoreLocalStorage=true&dependent=true&fromWebView=and"
    }

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        progressBar = findViewById(R.id.progressBar)

        applySystemBarInsets()
        configureWebView()
        attachClients()
        injectJavaScriptBridge()
        setupBackNavigation()

        Log.d(TAG, "Loading start URL: $START_URL")
        webView.loadUrl(START_URL)
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }

    /**
     * Enables JS, DOM storage, viewport, overview mode, and mixed content.
     */
    private fun configureWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            // Recommended defaults for a content WebView
            cacheMode = WebSettings.LOAD_DEFAULT
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
        }
        // Enable Chrome remote debugging only for debuggable builds
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
        Log.d(TAG, "WebView configured (JS, DOM storage, wide viewport, overview, mixed content)")
    }

    /**
     * Injects [BrowserBridge] so pages can call window.NativeApp.* methods.
     */
    private fun injectJavaScriptBridge() {
        val bridge = BrowserBridge(this)
        webView.addJavascriptInterface(bridge, BrowserBridge.INTERFACE_NAME)
        Log.d(TAG, "JS interface injected: ${BrowserBridge.INTERFACE_NAME}")
    }

    private fun attachClients() {
        webView.webViewClient = object : WebViewClient() {

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val url = request?.url?.toString().orEmpty()
                Log.d(TAG, "shouldOverrideUrlLoading: $url")
                // Keep navigation inside this WebView
                return false
            }

            @Deprecated("Deprecated in Java")
            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                Log.d(TAG, "shouldOverrideUrlLoading (legacy): $url")
                return false
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                Log.d(TAG, "onPageStarted: $url")
                progressBar.visibility = View.VISIBLE
                progressBar.progress = 0
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                Log.d(TAG, "onPageFinished / Page loaded: $url")
                progressBar.visibility = View.GONE
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                val failingUrl = request?.url?.toString().orEmpty()
                val description = error?.description?.toString().orEmpty()
                val errorCode = error?.errorCode ?: -1
                Log.d(TAG, "onReceivedError: code=$errorCode url=$failingUrl desc=$description")

                // Only show UI feedback for the main frame to avoid noise from subresources
                if (request?.isForMainFrame == true) {
                    Toast.makeText(
                        this@MainActivity,
                        getString(R.string.page_load_error, description.ifBlank { "Unknown" }),
                        Toast.LENGTH_LONG
                    ).show()
                    progressBar.visibility = View.GONE
                }
            }
        }

        webView.webChromeClient = object : WebChromeClient() {

            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                Log.d(TAG, "onProgressChanged: $newProgress%")
                progressBar.progress = newProgress
                progressBar.visibility = if (newProgress in 1..99) View.VISIBLE else View.GONE
            }

            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                val message = consoleMessage?.message().orEmpty()
                val source = consoleMessage?.sourceId().orEmpty()
                val line = consoleMessage?.lineNumber() ?: 0
                val level = consoleMessage?.messageLevel()?.name.orEmpty()
                Log.d(TAG, "JS console [$level] $source:$line — $message")
                return true
            }
        }
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (webView.canGoBack()) {
                        webView.goBack()
                    } else {
                        isEnabled = false
                        onBackPressedDispatcher.onBackPressed()
                    }
                }
            }
        )
    }

    override fun onDestroy() {
        // Tear down WebView cleanly to avoid leaks
        webView.apply {
            loadUrl("about:blank")
            stopLoading()
            clearHistory()
            removeAllViews()
            destroy()
        }
        super.onDestroy()
    }
}
