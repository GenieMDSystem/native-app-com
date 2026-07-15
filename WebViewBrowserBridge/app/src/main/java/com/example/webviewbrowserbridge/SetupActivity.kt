package com.example.webviewbrowserbridge

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.example.webviewbrowserbridge.data.AppPreferences
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText

/**
 * First-launch screen: subdomain + folder. Saved to app cache permanently until cleared.
 */
class SetupActivity : AppCompatActivity() {

    private lateinit var prefs: AppPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_setup)

        prefs = AppPreferences(this)

        val inputSubdomain = findViewById<TextInputEditText>(R.id.inputSubdomain)
        val inputFolder = findViewById<TextInputEditText>(R.id.inputFolder)

        // Defaults on first open
        inputSubdomain.setText(getString(R.string.default_subdomain))
        inputFolder.setText(getString(R.string.default_folder))

        findViewById<MaterialButton>(R.id.btnSaveConfig).setOnClickListener {
            val subdomain = inputSubdomain.text?.toString()?.trim().orEmpty()
            val folder = inputFolder.text?.toString()?.trim().orEmpty()

            if (subdomain.isBlank() || folder.isBlank()) {
                Toast.makeText(this, R.string.setup_validation_error, Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            prefs.saveConfig(subdomain = subdomain, folder = folder)
            Toast.makeText(this, R.string.setup_saved, Toast.LENGTH_SHORT).show()

            startActivity(Intent(this, LoginActivity::class.java))
            finish()
        }

        applySystemBarInsets()
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }
    }
}
