# iOS WebBridge

SwiftUI + WKWebView host that mirrors the Android app (`fromWebView=ios`).

## Run

1. Install **Xcode**
2. From the repo root, open `ios/WebBridge.xcodeproj`
3. Select an iPhone simulator or a signed device
4. Set your Development Team in Signing & Capabilities
5. Run (⌘R)

Flow: Splash → Setup (subdomain + folder) → Login → Home → WebView.

URLs use `fromWebView=ios` plus the same `disableCamera` / `forWR` flags as Android.

Home has a **Legacy WebView** toggle to reproduce the photo-picker hang vs the current `BridgeWebView`.
