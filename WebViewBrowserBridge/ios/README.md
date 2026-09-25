# iOS WebView Browser Bridge

SwiftUI + WKWebView host that mirrors the Android app, with a **native photo picker** so the page does not freeze after the iOS media sheet.

## Freeze fix

WKWebView’s built-in `<input type="file">` picker (Photo Library / Take Photo / Choose File) often never completes after dismiss when the app has **Limited Photos** access. The web page then looks frozen.

This iOS app:

1. Intercepts `input[type=file]` clicks in JavaScript
2. Opens **PHPicker** (no Photo Library permission — no “Private Access to Photos” banner)
3. Always returns a result to the page (`change` or `cancel`)
4. Does **not** declare `NSPhotoLibraryUsageDescription`

Do not add Photo Library permission to Info.plist. PHPicker does not need it.

## Run

1. Install **Xcode** (this Mac currently has only Command Line Tools)
2. Open `ios/WebViewBrowserBridge/WebViewBrowserBridge.xcodeproj`
3. Select an iPhone simulator or a signed device
4. Set your Development Team in Signing & Capabilities
5. Run (⌘R)

Flow: Setup (subdomain + folder) → Login → Home → WebView.

URLs use `fromWebView=ios` plus the same `disableCamera` / `forWR` flags as Android.

## Porting the picker into myhealth360UAT

If the freeze is in **myhealth360UAT** (the recorded app), copy these files into that WKWebView host:

- `NativeFilePicker.swift`
- `WebViewUserScripts.swift` (`fileInputIntercept`)
- The `NativeFilePicker` message handler in `WebViewScreen.swift`

And remove any `NSPhotoLibraryUsageDescription` / `PHPhotoLibrary.requestAuthorization` used only for this upload flow.
