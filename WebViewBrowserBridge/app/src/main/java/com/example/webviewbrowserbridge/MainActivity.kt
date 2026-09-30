package com.example.webviewbrowserbridge

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.example.webviewbrowserbridge.data.AppPreferences
import com.google.android.material.switchmaterial.SwitchMaterial

/**
 * Home screen after login. Opens WebViews with URLs built from cached config + profile.
 */
class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "WebViewBridge"
    }

    private lateinit var prefs: AppPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        prefs = AppPreferences(this)
        val config = prefs.getConfig()
        val session = prefs.getSession()

        if (config == null) {
            startActivity(Intent(this, SetupActivity::class.java))
            finish()
            return
        }
        if (session == null) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        setContentView(R.layout.activity_main)
        applySystemBarInsets()

        val profile = session.profile

        findViewById<TextView>(R.id.txtWelcome).text =
            getString(R.string.home_welcome, profile.displayName)

        val txtDomainInfo = findViewById<TextView>(R.id.txtDomainInfo)
        val switchLocal = findViewById<SwitchMaterial>(R.id.switchLocal)

        fun refreshHostLabel(useLocal: Boolean) {
            txtDomainInfo.text = if (useLocal) {
                getString(R.string.home_local_info)
            } else {
                config.environmentUrl
            }
        }

        switchLocal.isChecked = prefs.isLocalMode()
        refreshHostLabel(switchLocal.isChecked)
        switchLocal.setOnCheckedChangeListener { _, checked ->
            prefs.setLocalMode(checked)
            refreshHostLabel(checked)
        }

        findViewById<Button>(R.id.btnVisitDoctor).setOnClickListener {
            val url = AppDestinations.visitDoctorUrl(config, profile, switchLocal.isChecked)
            Log.d(TAG, "Visit Doctor URL: $url")
            openWebView(url)
        }

        findViewById<Button>(R.id.btnScheduleVisit).setOnClickListener {
            val url = AppDestinations.scheduleVisitUrl(config, profile, switchLocal.isChecked)
            Log.d(TAG, "Schedule Visit URL: $url")
            openWebView(url)
        }

        findViewById<Button>(R.id.btnSchedulesList).setOnClickListener {
            val url = AppDestinations.schedulesListUrl(config, profile, switchLocal.isChecked)
            Log.d(TAG, "Schedules List URL: $url")
            openWebView(url)
        }

        findViewById<Button>(R.id.btnLogout).setOnClickListener {
            prefs.clearSession()
            startActivity(
                Intent(this, LoginActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
            )
            finish()
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
