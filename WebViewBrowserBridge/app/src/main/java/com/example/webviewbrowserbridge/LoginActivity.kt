package com.example.webviewbrowserbridge

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.example.webviewbrowserbridge.data.AppPreferences
import com.example.webviewbrowserbridge.network.ApiException
import com.example.webviewbrowserbridge.network.GenieMdApi
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Username / password login against GenieMD ValidateLogin + Profile APIs.
 */
class LoginActivity : AppCompatActivity() {

    private lateinit var prefs: AppPreferences
    private val api = GenieMdApi()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        prefs = AppPreferences(this)

        val config = prefs.getConfig()
        if (config == null) {
            startActivity(Intent(this, SetupActivity::class.java))
            finish()
            return
        }

        findViewById<TextView>(R.id.txtDomainHint).text = config.environmentUrl

        val inputUsername = findViewById<TextInputEditText>(R.id.inputUsername)
        val inputPassword = findViewById<TextInputEditText>(R.id.inputPassword)
        val progress = findViewById<ProgressBar>(R.id.loginProgress)
        val btnLogin = findViewById<MaterialButton>(R.id.btnLogin)

        btnLogin.setOnClickListener {
            val username = inputUsername.text?.toString()?.trim().orEmpty()
            val password = inputPassword.text?.toString().orEmpty()

            if (username.isBlank() || password.isBlank()) {
                Toast.makeText(this, R.string.login_validation_error, Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            setLoading(progress, btnLogin, true)

            lifecycleScope.launch {
                try {
                    val login = withContext(Dispatchers.IO) {
                        api.validateLogin(config, username, password)
                    }
                    val profile = withContext(Dispatchers.IO) {
                        api.fetchProfile(config, login.token)
                    }

                    prefs.saveSession(login.token, profile)

                    startActivity(
                        Intent(this@LoginActivity, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                        }
                    )
                    finish()
                } catch (e: ApiException) {
                    Toast.makeText(this@LoginActivity, e.message, Toast.LENGTH_LONG).show()
                } catch (e: Exception) {
                    Toast.makeText(
                        this@LoginActivity,
                        getString(R.string.login_generic_error),
                        Toast.LENGTH_LONG
                    ).show()
                } finally {
                    setLoading(progress, btnLogin, false)
                }
            }
        }

        applySystemBarInsets()
    }

    private fun setLoading(progress: ProgressBar, btnLogin: MaterialButton, loading: Boolean) {
        progress.isVisible = loading
        btnLogin.isEnabled = !loading
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
