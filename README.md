# GenieMD WebView Browser Bridge

Same repo for Android and iOS WebView hosts.

| Platform | Path |
|----------|------|
| Android | [`WebViewBrowserBridge/`](WebViewBrowserBridge/) |
| iOS | [`ios/`](ios/) |

- Android README (links + native events): [`WebViewBrowserBridge/README.md`](WebViewBrowserBridge/README.md)
- iOS README: [`ios/README.md`](ios/README.md)

Open iOS in Xcode: `ios/WebBridge.xcodeproj`

Docs cover both `v2-splash-login-page` and `visit-doctor-optional-params`.

## Shared WebView links

| Branch | Links |
|--------|-------|
| `v2-splash-login-page` | Visit Doctor · Schedule Visit · **Schedules List** (`…/patient-schedule?fromWebView=…`) |
| `visit-doctor-optional-params` | Visit Doctor only (optional `dependent` / `ignoreLocationCheck`; multi-clinic) |

| Button | Path | Notable query params |
|--------|------|----------------------|
| Visit Doctor Now | `/assessment/#/protocol/{clinicID}/consent/{userID}` | `protocolName`, `dependent`, `fromWebView`, `ignoreLocationCheck`, `disableCamera`, `openPickerInNative`, **`forWR`**, **`showCQ`** (v2) |
| Schedule Visit Now | same assessment path | same without `forWR` / `showCQ` (v2) |
| Schedules List | `/rpm/#/webview/{clinicID}/{userID}/patient-schedule` | **`fromWebView` only** (v2 extra link) |

`fromWebView=android` on Android, `fromWebView=ios` on iOS.

## Native bridge (types 1–8)

| type | Meaning | Native → web |
|------|---------|--------------|
| 1 | Waiting room | — |
| 2 | Close WebView | — |
| 3 | Open schedule link | — |
| 4 | Photo picker | `window.onNativeImagePicked` |
| 5 | Video picker | `window.onNativeVideoPicked` |
| 6 | Document picker | `window.onNativeFilePicked` |
| 7 | Open a URL (`http(s)` / `tel:` / `mailto:` / `sms:`) | — (does not close) |
| 8 | Current location | `window.onNativeLocation` |

Full payloads: [`WebViewBrowserBridge/README.md`](WebViewBrowserBridge/README.md#native-bridge-events--detailed-reference).
