package com.example.webviewbrowserbridge

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.webviewbrowserbridge.data.AppPreferences

/**
 * Routes to Setup → Login → Home based on cached config and session.
 */
class LauncherActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = AppPreferences(this)
        val next = when {
            !prefs.hasConfig() -> SetupActivity::class.java
            !prefs.isLoggedIn() -> LoginActivity::class.java
            else -> MainActivity::class.java
        }

        startActivity(Intent(this, next))
        finish()
    }
}
