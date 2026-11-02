# GenieMD WebView Browser Bridge

Same repo for Android and iOS WebView hosts.

| Platform | Path |
|----------|------|
| Android | [`WebViewBrowserBridge/`](WebViewBrowserBridge/) |
| iOS | [`ios/`](ios/) |

- Android README: [`WebViewBrowserBridge/README.md`](WebViewBrowserBridge/README.md)
- iOS README: [`ios/README.md`](ios/README.md)

Open the iOS app in Xcode:

`ios/WebBridge.xcodeproj`

## Native bridge (types 1–8)

Web calls `NativeApp.callback(JSON.stringify({ type, data }))` or `window.callNative(type, data)`.

| type | Meaning | Native → web |
|------|---------|--------------|
| 1 | Waiting room | — |
| 2 | Close WebView | — |
| 3 | Open schedule link | — |
| 4 | Photo picker | `window.onNativeImagePicked` |
| 5 | Video picker | `window.onNativeVideoPicked` |
| 6 | Document picker | `window.onNativeFilePicked` |
| 7 | Open a URL | — (does not close WebView) |
| 8 | Current location | `window.onNativeLocation` |

Full send/receive payloads: [`WebViewBrowserBridge/README.md`](WebViewBrowserBridge/README.md#webview-native-bridge).
