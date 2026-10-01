package com.example.webviewbrowserbridge

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

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
    private lateinit var fileChooserHelper: WebViewFileChooserHelper
    private var cameraPhotoUri: Uri? = null
    private var pickerCancelledDelivered = false

    private var pickerAllowsMultiple = false

    /** Same callback iOS should use: window.onNativeImagePicked(jsonString). */
    private val nativeImagePickerSingle = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) {
            deliverNativeImageResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(listOf(uri))
    }

    private val nativeImagePicker = registerForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia()
    ) { uris ->
        if (uris.isNullOrEmpty()) {
            deliverNativeImageResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(uris)
    }

    private val takePicture = registerForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        val uri = cameraPhotoUri
        cameraPhotoUri = null
        if (!success || uri == null) {
            deliverNativeImageResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(listOf(uri))
    }

    private val cameraPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            launchCameraCapture()
        } else {
            Toast.makeText(this, R.string.picker_camera_unavailable, Toast.LENGTH_SHORT).show()
            deliverNativeImageResult(cancelled = true, files = emptyList())
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        permissionHelper = WebViewPermissionHelper(this)
        fileChooserHelper = WebViewFileChooserHelper(this)

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

    override fun openNativeImagePicker(multiple: Boolean) {
        Log.d(TAG, "Opening native photo picker chooser multiple=$multiple")
        pickerAllowsMultiple = multiple
        pickerCancelledDelivered = false
        val options = buildList {
            if (packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
                add(getString(R.string.picker_take_photo))
            }
            add(getString(R.string.picker_photo_library))
        }.toTypedArray()

        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.picker_title)
            .setItems(options) { _, which ->
                when (options[which]) {
                    getString(R.string.picker_take_photo) -> requestCameraThenCapture()
                    else -> launchPhotoLibrary()
                }
            }
            .setNegativeButton(R.string.picker_cancel) { _, _ ->
                deliverNativeImageResult(cancelled = true, files = emptyList())
            }
            .setOnCancelListener {
                deliverNativeImageResult(cancelled = true, files = emptyList())
            }
            .show()
    }

    private fun launchPhotoLibrary() {
        val request = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
        if (pickerAllowsMultiple) {
            nativeImagePicker.launch(request)
        } else {
            nativeImagePickerSingle.launch(request)
        }
    }

    private fun requestCameraThenCapture() {
        val granted = ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        if (granted) {
            launchCameraCapture()
        } else {
            cameraPermission.launch(android.Manifest.permission.CAMERA)
        }
    }

    private fun launchCameraCapture() {
        try {
            val photoFile = File(
                File(cacheDir, "images").apply { mkdirs() },
                "CAMERA_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}.jpg"
            )
            val outputUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                photoFile
            )
            cameraPhotoUri = outputUri
            takePicture.launch(outputUri)
        } catch (e: Exception) {
            Log.d(TAG, "Error launching camera", e)
            Toast.makeText(this, R.string.picker_camera_unavailable, Toast.LENGTH_SHORT).show()
            deliverNativeImageResult(cancelled = true, files = emptyList())
        }
    }

    private fun encodeUrisOnBackground(uris: List<Uri>) {
        Thread {
            val files = uris.mapNotNull { encodeImageForWeb(it) }
            runOnUiThread {
                if (files.isEmpty()) {
                    deliverNativeImageResult(cancelled = true, files = emptyList())
                } else {
                    deliverNativeImageResult(cancelled = false, files = files)
                }
            }
        }.start()
    }

    /**
     * Generic return for iOS and Android.
     * Success: { cancelled: false, success: true, files: [{ mimeType, dataUrl }] }
     * Cancel:  { cancelled: true, success: false, files: [] }
     */
    private fun deliverNativeImageResult(
        cancelled: Boolean,
        files: List<Pair<String, String>>
    ) {
        if (!::webView.isInitialized) {
            return
        }
        val fileArray = JSONArray()
        files.forEach { (mimeType, dataUrl) ->
            fileArray.put(JSONObject().apply {
                put("mimeType", mimeType)
                put("dataUrl", dataUrl)
            })
        }
        val payload = JSONObject().apply {
            put("cancelled", cancelled)
            put("success", !cancelled && fileArray.length() > 0)
            put("files", fileArray)
        }
        if (cancelled && pickerCancelledDelivered) {
            return
        }
        if (cancelled) {
            pickerCancelledDelivered = true
        }
        val script = "window.onNativeImagePicked(${JSONObject.quote(payload.toString())})"
        Log.d(TAG, "onNativeImagePicked cancelled=$cancelled count=${fileArray.length()}")
        webView.evaluateJavascript(script, null)
    }

    private fun encodeImageForWeb(uri: Uri): Pair<String, String>? {
        return try {
            val bitmap = contentResolver.openInputStream(uri)?.use { input ->
                BitmapFactory.decodeStream(input)
            } ?: return null
            val scaled = scaleDown(bitmap, 1600)
            val output = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, output)
            if (scaled !== bitmap) {
                bitmap.recycle()
                scaled.recycle()
            } else {
                bitmap.recycle()
            }
            val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
            "image/jpeg" to "data:image/jpeg;base64,$base64"
        } catch (e: Exception) {
            Log.d(TAG, "Error encoding picked image", e)
            null
        }
    }

    private fun scaleDown(source: Bitmap, maxEdge: Int): Bitmap {
        val largest = maxOf(source.width, source.height)
        if (largest <= maxEdge) {
            return source
        }
        val ratio = maxEdge.toFloat() / largest
        return Bitmap.createScaledBitmap(
            source,
            (source.width * ratio).toInt().coerceAtLeast(1),
            (source.height * ratio).toInt().coerceAtLeast(1),
            true
        )
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
        // Android WebView adds X-Requested-With: <package> on every request, including
        // Angular uploads. The desktop browser does not, and the AWS load balancer
        // in front of the API returns 403 for that header. An empty allow-list
        // stops the header from being sent.
        if (WebViewFeature.isFeatureSupported(WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST)) {
            WebSettingsCompat.setRequestedWithHeaderOriginAllowList(webView.settings, emptySet())
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

            /**
             * Required for &lt;input type="file"&gt; — opens gallery / file manager / camera.
             */
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                if (webView == null || filePathCallback == null || fileChooserParams == null) {
                    return false
                }
                return fileChooserHelper.onShowFileChooser(
                    webView,
                    filePathCallback,
                    fileChooserParams
                )
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
        fileChooserHelper.cancel()
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
