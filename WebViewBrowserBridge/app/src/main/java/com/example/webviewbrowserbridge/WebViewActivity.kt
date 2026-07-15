package com.example.webviewbrowserbridge

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
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
 * Full-screen WebView (no top bar) with [BrowserBridge] injected as NativeApp.
 */
class WebViewActivity : AppCompatActivity(), BridgeCallbackHost {

    companion object {
        private const val TAG = "WebViewBridge"
        private const val EXTRA_URL = "extra_url"

        fun createIntent(context: Context, url: String): Intent {
            return Intent(context, WebViewActivity::class.java).apply {
                putExtra(EXTRA_URL, url)
            }
        }
    }

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var permissionHelper: WebViewPermissionHelper

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        permissionHelper = WebViewPermissionHelper(this)

        setContentView(R.layout.activity_webview)

        val startUrl = intent.getStringExtra(EXTRA_URL).orEmpty()

        webView = findViewById(R.id.webView)
        progressBar = findViewById(R.id.progressBar)

        applySystemBarInsets()
        configureWebView()
        attachClients()
        injectJavaScriptBridge()
        setupBackNavigation()

        // Ask once when WebView opens so camera/mic/location work without extra taps
        permissionHelper.requestCommonPermissionsIfNeeded()

        Log.d(TAG, "WebViewActivity loading: $startUrl")
        webView.loadUrl(startUrl)
    }

    override fun loadUrlInWebView(url: String) {
        Log.d(TAG, "Bridge requested WebView navigation: $url")
        webView.loadUrl(url)
    }

    override fun finishWithResult() {
        Log.d(TAG, "Bridge closed WebView — returning to main screen")
        finish()
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }

    private fun configureWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            cacheMode = WebSettings.LOAD_DEFAULT
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            // Required for navigator.geolocation in WebView
            setGeolocationEnabled(true)
            // Allow audio/video playback without a user tap (optional; many telehealth flows need this)
            mediaPlaybackRequiresUserGesture = false
        }
        if ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
        Log.d(TAG, "WebView configured")
    }

    private fun injectJavaScriptBridge() {
        webView.addJavascriptInterface(BrowserBridge(this, this), BrowserBridge.INTERFACE_NAME)
        Log.d(TAG, "JS interface injected: ${BrowserBridge.INTERFACE_NAME}")
    }

    private fun attachClients() {
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                Log.d(TAG, "shouldOverrideUrlLoading: ${request?.url}")
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
                val description = error?.description?.toString().orEmpty()
                Log.d(TAG, "onReceivedError: $description url=${request?.url}")
                if (request?.isForMainFrame == true) {
                    Toast.makeText(
                        this@WebViewActivity,
                        getString(R.string.page_load_error, description.ifBlank { "Unknown" }),
                        Toast.LENGTH_LONG
                    ).show()
                    progressBar.visibility = View.GONE
                }
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar.progress = newProgress
                progressBar.visibility = if (newProgress in 1..99) View.VISIBLE else View.GONE
            }

            /**
             * Grants camera / microphone when the page calls navigator.mediaDevices.getUserMedia().
             */
            override fun onPermissionRequest(request: PermissionRequest?) {
                if (request == null) return
                permissionHelper.onWebPermissionRequest(request)
            }

            /**
             * Grants location when the page calls navigator.geolocation.
             */
            override fun onGeolocationPermissionsShowPrompt(
                origin: String?,
                callback: GeolocationPermissions.Callback?
            ) {
                if (callback == null) return
                permissionHelper.onGeolocationRequest(origin, callback)
            }

            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                Log.d(
                    TAG,
                    "JS console [${consoleMessage?.messageLevel()}] " +
                        "${consoleMessage?.sourceId()}:${consoleMessage?.lineNumber()} — " +
                        consoleMessage?.message()
                )
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
                        finish()
                    }
                }
            }
        )
    }

    override fun onDestroy() {
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
