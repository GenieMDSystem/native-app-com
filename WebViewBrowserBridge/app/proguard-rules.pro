# Keep JavascriptInterface methods so the bridge survives obfuscation.
-keepclassmembers class com.example.webviewbrowserbridge.BrowserBridge {
    @android.webkit.JavascriptInterface <methods>;
}
