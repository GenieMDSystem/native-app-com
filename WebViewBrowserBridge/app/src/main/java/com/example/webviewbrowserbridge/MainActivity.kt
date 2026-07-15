package com.example.webviewbrowserbridge

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

/**
 * Native home screen. Each button opens [WebViewActivity] with a destination URL.
 */
class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "WebViewBridge"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        applySystemBarInsets()

        findViewById<Button>(R.id.btnVisitDoctor).setOnClickListener {
            Log.d(TAG, "Home: Visit Doctor Now")
            openWebView(AppDestinations.VISIT_DOCTOR_URL)
        }

        findViewById<Button>(R.id.btnScheduleVisit).setOnClickListener {
            Log.d(TAG, "Home: Schedule Visit Now")
            openWebView(AppDestinations.SCHEDULE_VISIT_URL)
        }

        findViewById<Button>(R.id.btnSchedulesList).setOnClickListener {
            Log.d(TAG, "Home: Schedules List")
            openWebView(AppDestinations.SCHEDULES_LIST_URL)
        }
    }

    private fun openWebView(url: String) {
        startActivity(WebViewActivity.createIntent(this, url))
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                view.paddingLeft + bars.left,
                view.paddingTop + bars.top,
                view.paddingRight + bars.right,
                view.paddingBottom + bars.bottom
            )
            insets
        }
    }
}
