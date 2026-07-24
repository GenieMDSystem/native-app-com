# WebViewBrowserBridge

Kotlin Android app that:

1. Saves environment config (subdomain + folder) and user session
2. Builds **three WebView URLs** from that data
3. Hosts those pages in a native WebView with a **JavaScript bridge** (`NativeApp`)

---

## How the three links are constructed

URL builders live in `AppDestinations.kt`.  
Values come from:

| Source | Fields |
|--------|--------|
| Setup (cached) | `subdomain`, `folder` → `baseUrl` = `https://{subdomain}.geniemd.net` |
| Profile (after login) | `clinicID`, `userID`, `languageId`, `oemID` |

### 1. Visit Doctor Now (Waiting Room)

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocalStorage=true
```

Built by: `AppDestinations.visitDoctorUrl(config, profile)`

### 2. Schedule Visit Now

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20Scheudle%20a%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocationCheck=true
```

Built by: `AppDestinations.scheduleVisitUrl(config, profile)`

### 3. Schedules List

```
https://{subdomain}.geniemd.net/{folder}/rpm/#/webview/{clinicID}/{userID}/patient-schedule
  ?fromWebView=android
```

Built by: `AppDestinations.schedulesListUrl(config, profile)`

### Example

With `subdomain=dev`, `folder=neurofinity`, `clinicID=1000254`, `userID=0b4a…`, `languageId=1`, `oemID=100`:

```
https://dev.geniemd.net/neurofinity/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&protocolName=Revamp%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocalStorage=true
```

---

## WebView native bridge

The WebView injects a JavaScript interface named **`NativeApp`**.

Web pages call:

```javascript
NativeApp.callback(JSON.stringify({ type: number, data: { ... } }));
```

Native handler: `BrowserBridge.callback(json)` in `BrowserBridge.kt`.

### Callback types

#### Type `1` — Waiting room

```json
{
  "type": 1,
  "data": {
    "url": "https://example.com",
    "success": true,
    "openInBrowser": true
  }
}
```

| Field | Behavior |
|-------|----------|
| `success: false` | Show error toast; do nothing else |
| `openInBrowser: true` | Open `url` in the system browser, then close WebView → home |
| `openInBrowser: false` | Load `url` inside the same WebView |

#### Type `2` — Close WebView (return home)

```json
{
  "type": 2,
  "data": { "success": true }
}
```

or:

```json
{
  "type": 2,
  "data": { "close": true }
}
```

If `success` **or** `close` is `true`, the WebView closes and the app returns to the home screen.

#### Type `3` — Open schedule link

```json
{
  "type": 3,
  "data": {
    "url": "https://example.com/schedule/1",
    "success": true,
    "openInBrowser": true
  }
}
```

Same rules as type `1` (browser vs WebView, then return home when opening the browser).

### Why `@JavascriptInterface`?

Only methods annotated with `@JavascriptInterface` are callable from JavaScript (API 17+). This limits exposure and avoids reflecting arbitrary native methods into the page.

### How to use from any loaded page

```javascript
function sendToNative(type, data) {
  if (window.NativeApp && window.NativeApp.callback) {
    window.NativeApp.callback(JSON.stringify({ type: type, data: data }));
  } else {
    console.warn("Native bridge not available");
  }
}

// Close WebView → home
sendToNative(2, { close: true });

// Open link in mobile browser, then go home
sendToNative(1, {
  url: "https://example.com",
  success: true,
  openInBrowser: true
});
```

Always check `window.NativeApp` so the same page can run in a normal browser without crashing.

### Security notes

- Only expose a narrow callback API (types 1–3).
- Validate URLs (`http` / `https` with a host) before opening.
- Prefer loading trusted origins only.
- Keep ProGuard rules for `@JavascriptInterface` methods if minify is enabled.

---

## App flow (context)

```
Launcher → Setup (first time) → Login → Home (3 buttons) → WebView
                                      ↑______________________|
                                         type 2 close / logout
```

- **Setup:** subdomain + folder (defaults `dev` / `prod`), saved in SharedPreferences  
- **Login:** ValidateLogin → Profile → stores `userID`, `clinicID`, `languageId`, `oemID`  
- **Home:** builds the three URLs above and opens `WebViewActivity`  
- **Logout:** clears session only; config remains  

---

## Key files

| File | Purpose |
|------|---------|
| `AppDestinations.kt` | Constructs the three WebView URLs |
| `BrowserBridge.kt` | Native bridge (`NativeApp.callback`) |
| `WebViewActivity.kt` | Full-screen WebView host |
| `MainActivity.kt` | Home buttons that open each URL |
| `data/AppPreferences.kt` | Cached config + session |
| `network/GenieMdApi.kt` | Login + profile APIs |

---

## Logcat

Filter tag: **`WebViewBridge`**

Useful messages: URL loads, bridge callbacks, browser launch, permission / file-chooser events.
