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
| Setup (cached) | `subdomain`, `folder` → `baseUrl` = `https://{subdomain}.geniemd.net` · `environmentUrl` = `https://{subdomain}.geniemd.net/{folder}` |
| Profile (after login) | `clinicID`, `userID`, `languageId`, `oemID` |

### New query params

These flags were added to the WebView URLs:

| Param | Value | Visit Doctor Now | Schedule Visit Now | Schedules List |
|-------|-------|------------------|--------------------|----------------|
| **`disableCamera`** **(new)** | `true` | yes | yes | no |
| **`forWR`** **(new)** | `true` | yes | no | no |

All other query params (`patientLanguageID`, `patientOEMID`, `protocolName`, `dependent`, `fromWebView`, `ignoreLocationCheck`) are unchanged.

### 1. Visit Doctor Now (Waiting Room)

`AppDestinations.visitDoctorUrl(config, profile)`

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocationCheck=true
  &disableCamera=true          # NEW
  &forWR=true                  # NEW — Visit Doctor only
```

### 2. Schedule Visit Now

`AppDestinations.scheduleVisitUrl(config, profile)`

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20Scheudle%20a%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocationCheck=true
  &disableCamera=true          # NEW
```

### 3. Schedules List

`AppDestinations.schedulesListUrl(config, profile)`

```
https://{subdomain}.geniemd.net/{folder}/rpm/#/webview/{clinicID}/{userID}/patient-schedule
  ?fromWebView=android
```

### Example

New query params are called out below the full URL.

With defaults `subdomain=mhc`, `folder=apps2`, and profile `clinicID=1000254`, `userID=0b4a…`, `languageId=1`, `oemID=100`:

**Visit Doctor:**
```
https://mhc.geniemd.net/apps2/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&protocolName=Revamp%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true&forWR=true
```
**New:** `disableCamera=true`, `forWR=true`

**Schedule Visit:**
```
https://mhc.geniemd.net/apps2/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&protocolName=Revamp%20Scheudle%20a%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true
```
**New:** `disableCamera=true`

**Schedules List:**
```
https://mhc.geniemd.net/apps2/rpm/#/webview/1000254/0b4a…/patient-schedule?fromWebView=android
```
No new query params.

---

## Configuring for production / other environments

Update URL building in `AppDestinations.kt` (and Setup defaults in `strings.xml` if needed).

### Domain and folder

On first launch (Setup screen), or by changing defaults:

| Field | Sample (current) | Production example |
|-------|------------------|--------------------|
| Subdomain | `mhc` | your prod subdomain (e.g. `www`, `app`, clinic code) |
| Folder | `apps2` | your prod folder (e.g. `apps`, `prod`) |

Resulting base: `https://{subdomain}.geniemd.net/{folder}`

Defaults live in `res/values/strings.xml`:

```xml
<string name="default_subdomain">mhc</string>
<string name="default_folder">apps2</string>
```

Users can also enter production values on the Setup screen; they are saved in SharedPreferences.

### `protocolName` — use the correct protocol title

These query values must match the **exact protocol names** configured in your GenieMD / assessment backend:

| Button | Current sample value | Notes |
|--------|----------------------|--------|
| Visit Doctor | `Revamp%20TeleConsultation` | URL-encoded; use your prod waiting-room / teleconsult protocol name |
| Schedule Visit | `Revamp%20Scheudle%20a%20TeleConsultation` | URL-encoded; use your prod schedule protocol name |

Change them in `AppDestinations.kt` where the query string is appended, for example:

```kotlin
// Visit Doctor — replace with your production protocol name
append("&protocolName=Your%20Production%20TeleConsultation&...")

// Schedule Visit — replace with your production schedule protocol name
append("&protocolName=Your%20Production%20Schedule%20Name&...")
```

Spaces must be encoded as `%20`.

### `dependent=true` — optional

`&dependent=true` is appended today for Visit Doctor and Schedule Visit.

- **Keep it** if the web flow should run in dependent mode.
- **Remove it** if you do not want dependent behavior — simply do not append `&dependent=true` in `AppDestinations.kt`.

Schedules List does not use `dependent`.

### `disableCamera=true` **(new)**

`&disableCamera=true` is appended for **Visit Doctor Now** and **Schedule Visit Now**.

Schedules List does not use `disableCamera`.

### `forWR=true` — Visit Doctor only **(new)**

`&forWR=true` is appended only on **Visit Doctor Now** (waiting room).

Schedule Visit Now and Schedules List do not include `forWR`.

### Android vs iOS — `fromWebView`

| Platform | Query value |
|----------|-------------|
| Android (this app) | `fromWebView=android` |
| iOS | `fromWebView=ios` |

For an iOS WebView host, use the **same URL shapes** and only change:

```
fromWebView=android  →  fromWebView=ios
```

Apply that change on all three links (Visit Doctor, Schedule Visit, Schedules List). The rest of the path and query params stay the same.

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

- **Setup:** subdomain + folder (defaults `mhc` / `apps2`), saved in SharedPreferences  
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
