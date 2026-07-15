package com.example.webviewbrowserbridge

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Handles &lt;input type="file"&gt; from WebView via [WebChromeClient.onShowFileChooser].
 */
class WebViewFileChooserHelper(private val activity: AppCompatActivity) {

    companion object {
        private const val TAG = "WebViewBridge"
    }

    private var filePathCallback: ValueCallback<Array<Uri>>? = null
    private var cameraPhotoUri: Uri? = null

    private val fileChooserLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        deliverResult(result.resultCode == Activity.RESULT_OK, result.data)
    }

    /**
     * @return true if this helper handled the request (always, when called).
     */
    fun onShowFileChooser(
        webView: WebView,
        filePathCallback: ValueCallback<Array<Uri>>,
        fileChooserParams: WebChromeClient.FileChooserParams
    ): Boolean {
        // Cancel any pending callback
        this.filePathCallback?.onReceiveValue(null)
        this.filePathCallback = filePathCallback

        val acceptTypes = fileChooserParams.acceptTypes
            ?.filter { it.isNotBlank() }
            ?.toTypedArray()
            ?: arrayOf("*/*")

        val allowMultiple = fileChooserParams.mode == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE
        val captureEnabled = fileChooserParams.isCaptureEnabled

        Log.d(
            TAG,
            "File chooser accept=${acceptTypes.joinToString()} capture=$captureEnabled multiple=$allowMultiple"
        )

        val pickIntent = buildPickIntent(acceptTypes, allowMultiple)
        val intents = mutableListOf<Intent>()

        if (!captureEnabled) {
            intents.add(pickIntent)
        }

        if (acceptsImages(acceptTypes)) {
            createCameraIntent()?.let { intents.add(it) }
        }

        if (intents.isEmpty()) {
            intents.add(pickIntent)
        }

        val chooserTitle = if (captureEnabled) "Take or upload photo" else "Choose file"
        val chooser = if (intents.size == 1) {
            intents.first()
        } else {
            Intent.createChooser(intents.removeAt(0), chooserTitle).apply {
                putExtra(Intent.EXTRA_INITIAL_INTENTS, intents.toTypedArray())
            }
        }

        return try {
            fileChooserLauncher.launch(chooser)
            true
        } catch (e: Exception) {
            Log.d(TAG, "Error launching file chooser", e)
            cancel()
            false
        }
    }

    private fun buildPickIntent(acceptTypes: Array<String>, allowMultiple: Boolean): Intent {
        return Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = resolveMimeType(acceptTypes)
            if (acceptTypes.isNotEmpty() && acceptTypes[0] != "*/*") {
                putExtra(Intent.EXTRA_MIME_TYPES, acceptTypes)
            }
            if (allowMultiple) {
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }
    }

    private fun createCameraIntent(): Intent? {
        return try {
            val photoFile = createImageFile()
            cameraPhotoUri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                photoFile
            )
            Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, cameraPhotoUri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }
        } catch (e: Exception) {
            Log.d(TAG, "Error creating camera intent", e)
            null
        }
    }

    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val dir = File(activity.cacheDir, "images").apply { mkdirs() }
        return File.createTempFile("WEBVIEW_${timeStamp}_", ".jpg", dir)
    }

    private fun deliverResult(success: Boolean, data: Intent?) {
        val callback = filePathCallback ?: return
        filePathCallback = null

        if (!success) {
            callback.onReceiveValue(null)
            cameraPhotoUri = null
            return
        }

        val uris = extractUris(data) ?: cameraPhotoUri?.let { arrayOf(it) }
        Log.d(TAG, "File chooser result: ${uris?.joinToString()}")
        callback.onReceiveValue(uris)
        cameraPhotoUri = null
    }

    private fun extractUris(data: Intent?): Array<Uri>? {
        if (data == null) return null
        data.data?.let { return arrayOf(it) }
        data.clipData?.let { clip ->
            return Array(clip.itemCount) { clip.getItemAt(it).uri }
        }
        return null
    }

    private fun resolveMimeType(acceptTypes: Array<String>): String {
        return acceptTypes.firstOrNull { it.isNotBlank() && it != "*/*" } ?: "*/*"
    }

    private fun acceptsImages(acceptTypes: Array<String>): Boolean {
        return acceptTypes.any { type ->
            type.startsWith("image/") || type == "image/*" || type == "*/*"
        }
    }

    fun cancel() {
        filePathCallback?.onReceiveValue(null)
        filePathCallback = null
        cameraPhotoUri = null
    }
}
