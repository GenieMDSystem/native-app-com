package com.example.webviewbrowserbridge

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
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
        private const val MAX_PASS_THROUGH_BYTES = 1_500_000
        private const val MAX_BRIDGE_FILE_BYTES = 20_000_000
        private val PASS_THROUGH_MIMES = setOf(
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/gif",
        )

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
    private lateinit var locationHelper: NativeLocationHelper
    private var cameraPhotoUri: Uri? = null
    private var pickerCancelledDelivered = false
    private var pendingPickerCallback = NativePickerCallback.IMAGE

    private var pickerAllowsMultiple = false

    /** Same callback iOS should use: window.onNativeImagePicked(jsonString). */
    private val nativeImagePickerSingle = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) {
            deliverNativePickerResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(listOf(uri))
    }

    private val nativeImagePicker = registerForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia()
    ) { uris ->
        if (uris.isNullOrEmpty()) {
            deliverNativePickerResult(cancelled = true, files = emptyList())
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
            deliverNativePickerResult(cancelled = true, files = emptyList())
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
            deliverNativePickerResult(cancelled = true, files = emptyList())
        }
    }

    private val nativeVideoPicker = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) {
            deliverNativePickerResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(listOf(uri), NativePickerCallback.VIDEO)
    }

    private val nativeFilePicker = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        if (uri == null) {
            deliverNativePickerResult(cancelled = true, files = emptyList())
            return@registerForActivityResult
        }
        encodeUrisOnBackground(listOf(uri), NativePickerCallback.FILE)
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        permissionHelper = WebViewPermissionHelper(this)
        fileChooserHelper = WebViewFileChooserHelper(this)
        locationHelper = NativeLocationHelper(this) { payload ->
            deliverJsCallback("onNativeLocation", payload)
        }

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
        beginPicker(NativePickerCallback.IMAGE)
        pickerAllowsMultiple = multiple
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
                deliverNativePickerResult(cancelled = true, files = emptyList())
            }
            .setOnCancelListener {
                deliverNativePickerResult(cancelled = true, files = emptyList())
            }
            .show()
    }

    override fun openNativeVideoPicker() {
        Log.d(TAG, "Opening native video picker")
        beginPicker(NativePickerCallback.VIDEO)
        nativeVideoPicker.launch(
            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.VideoOnly)
        )
    }

    override fun openNativeFilePicker() {
        Log.d(TAG, "Opening native document picker")
        beginPicker(NativePickerCallback.FILE)
        nativeFilePicker.launch("*/*")
    }

    override fun getNativeLocation(enableHighAccuracy: Boolean, timeoutMs: Long) {
        Log.d(TAG, "Requesting native location highAccuracy=$enableHighAccuracy timeout=$timeoutMs")
        locationHelper.request(enableHighAccuracy, timeoutMs)
    }

    private fun beginPicker(callback: NativePickerCallback) {
        pendingPickerCallback = callback
        pickerCancelledDelivered = false
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
            deliverNativePickerResult(cancelled = true, files = emptyList())
        }
    }

    private fun encodeUrisOnBackground(
        uris: List<Uri>,
        callback: NativePickerCallback = pendingPickerCallback,
    ) {
        Thread {
            val files = uris.mapNotNull { encodeUriForWeb(it, callback) }
            runOnUiThread {
                if (files.isEmpty()) {
                    deliverNativePickerResult(cancelled = true, files = emptyList(), callback = callback)
                } else {
                    deliverNativePickerResult(cancelled = false, files = files, callback = callback)
                }
            }
        }.start()
    }

    /**
     * Generic return for iOS and Android.
     * Success: { cancelled: false, success: true, files: [{ mimeType, fileName, dataUrl }] }
     * Cancel:  { cancelled: true, success: false, files: [] }
     */
    private fun deliverNativePickerResult(
        cancelled: Boolean,
        files: List<NativePickedFile>,
        callback: NativePickerCallback = pendingPickerCallback,
    ) {
        if (!::webView.isInitialized) {
            return
        }
        val fileArray = JSONArray()
        files.forEach { file ->
            fileArray.put(JSONObject().apply {
                put("mimeType", file.mimeType)
                put("fileName", file.fileName)
                put("dataUrl", file.dataUrl)
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
        Log.d(TAG, "${callback.jsName} cancelled=$cancelled count=${fileArray.length()}")
        deliverJsCallback(callback.jsName, payload)
    }

    private fun deliverJsCallback(functionName: String, payload: JSONObject) {
        if (!::webView.isInitialized) {
            return
        }
        val script = "window.$functionName && window.$functionName(${JSONObject.quote(payload.toString())})"
        webView.evaluateJavascript(script, null)
    }

    /**
     * Sends the original file bytes. Decoding the picker stream with
     * BitmapFactory.decodeStream and recompressing produced a smeared JPEG
     * that the upload API rejects. A normal file of the same picture succeeds.
     */
    private fun encodeUriForWeb(uri: Uri, callback: NativePickerCallback): NativePickedFile? {
        return when (callback) {
            NativePickerCallback.IMAGE -> encodeImageForWeb(uri)
            NativePickerCallback.VIDEO -> encodeBytesForWeb(uri, "native-video", "video/mp4")
            NativePickerCallback.FILE -> encodeBytesForWeb(uri, "native-file", "application/octet-stream")
        }
    }

    private fun encodeBytesForWeb(
        uri: Uri,
        fallbackName: String,
        defaultMime: String,
    ): NativePickedFile? {
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
            if (bytes.isEmpty() || bytes.size > MAX_BRIDGE_FILE_BYTES) {
                Log.d(TAG, "Skipped native file emptyOrTooLarge size=${bytes.size}")
                return null
            }
            val mimeType = reportedMime(contentResolver.getType(uri), defaultMime)
            val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
            NativePickedFile(
                mimeType = mimeType,
                dataUrl = "data:$mimeType;base64,$base64",
                fileName = displayName(uri) ?: "$fallbackName.${extensionFor(mimeType)}",
            )
        } catch (e: Exception) {
            Log.d(TAG, "Error encoding picked file", e)
            null
        }
    }

    private fun reportedMime(reported: String?, fallback: String): String {
        val normalized = reported?.substringBefore(';')?.lowercase()?.takeIf { it.isNotBlank() }
        return when {
            normalized == null -> fallback
            normalized == "image/jpg" -> "image/jpeg"
            else -> normalized
        }
    }

    private fun encodeImageForWeb(uri: Uri): NativePickedFile? {
        return try {
            val original = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
            if (original.isEmpty()) {
                return null
            }
            val sourceMime = imageMime(contentResolver.getType(uri), original)
            val passThrough = sourceMime in PASS_THROUGH_MIMES && original.size <= MAX_PASS_THROUGH_BYTES
            val bytes = if (passThrough) original else recompressImage(original)
            val mimeType = if (bytes === original) sourceMime else "image/jpeg"
            val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
            NativePickedFile(
                mimeType = mimeType,
                dataUrl = "data:$mimeType;base64,$base64",
                fileName = displayName(uri) ?: "native-photo.${extensionFor(mimeType)}",
            )
        } catch (e: Exception) {
            Log.d(TAG, "Error encoding picked image", e)
            null
        }
    }

    private fun recompressImage(bytes: ByteArray): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return bytes
        val scaled = scaleDown(bitmap, 1600)
        return try {
            val output = ByteArrayOutputStream()
            if (!scaled.compress(Bitmap.CompressFormat.JPEG, 90, output)) {
                bytes
            } else {
                output.toByteArray()
            }
        } finally {
            if (scaled !== bitmap) {
                scaled.recycle()
            }
            bitmap.recycle()
        }
    }

    private fun displayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    null
                } else {
                    cursor.getString(0)?.takeIf { it.isNotBlank() }
                }
            }
    }

    private fun imageMime(reported: String?, bytes: ByteArray): String {
        val normalized = reported?.substringBefore(';')?.lowercase()
        if (normalized != null && normalized.startsWith("image/") && normalized != "image/jpg") {
            return normalized
        }
        if (normalized == "image/jpg") {
            return "image/jpeg"
        }
        return when {
            bytes.size >= 3 && bytes[0] == 0xFF.toByte() && bytes[1] == 0xD8.toByte() -> "image/jpeg"
            bytes.size >= 8 && bytes.copyOfRange(0, 8).contentEquals(
                byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
            ) -> "image/png"
            bytes.size >= 12 &&
                bytes.copyOfRange(0, 4).contentEquals("RIFF".toByteArray()) &&
                bytes.copyOfRange(8, 12).contentEquals("WEBP".toByteArray()) -> "image/webp"
            bytes.size >= 6 && (
                bytes.copyOfRange(0, 6).contentEquals("GIF87a".toByteArray()) ||
                    bytes.copyOfRange(0, 6).contentEquals("GIF89a".toByteArray())
                ) -> "image/gif"
            else -> "image/jpeg"
        }
    }

    private fun extensionFor(mimeType: String): String {
        return when (mimeType) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/gif" -> "gif"
            "video/mp4" -> "mp4"
            "application/pdf" -> "pdf"
            "application/octet-stream" -> "bin"
            else -> mimeType.substringAfter('/', "bin").substringBefore('+').ifBlank { "bin" }
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
        try {
            if (WebViewFeature.isFeatureSupported(WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST)) {
                WebSettingsCompat.setRequestedWithHeaderOriginAllowList(webView.settings, emptySet())
                Log.d(TAG, "X-Requested-With header disabled")
            } else {
                Log.d(TAG, "X-Requested-With allow-list is not supported by this WebView")
            }
        } catch (e: Exception) {
            Log.d(TAG, "Unable to disable X-Requested-With", e)
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

    /** PTX prefers window.callNative(type, data) and falls back to NativeApp.callback. */
    private fun injectCallNative() {
        val script = """
            (function() {
              if (window.callNative) { return; }
              window.callNative = function(type, data) {
                if (window.NativeApp && window.NativeApp.callback) {
                  window.NativeApp.callback(JSON.stringify({ type: type, data: data }));
                  return true;
                }
                return false;
              };
            })();
        """.trimIndent()
        webView.evaluateJavascript(script, null)
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
                injectCallNative()
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
        locationHelper.cancel()
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

private data class NativePickedFile(
    val mimeType: String,
    val dataUrl: String,
    val fileName: String,
)

private enum class NativePickerCallback(val jsName: String) {
    IMAGE("onNativeImagePicked"),
    VIDEO("onNativeVideoPicked"),
    FILE("onNativeFilePicked"),
}
