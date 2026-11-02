# WebViewBrowserBridge

Kotlin Android app that:

1. Saves environment config (subdomain + folder) and user session
2. Builds the **Visit Doctor** WebView URL from that data
3. Hosts that page in a native WebView with a **JavaScript bridge** (`NativeApp`)

Home UI is **Visit Doctor** plus **Logout**. Optional query flags are checkboxes.

---

## How the Visit Doctor link is constructed

URL builder lives in `AppDestinations.kt`.  
Values come from:

| Source | Fields |
|--------|--------|
| Setup (cached) | `subdomain`, `folder` → `baseUrl` = `https://{subdomain}.geniemd.net` · `environmentUrl` = `https://{subdomain}.geniemd.net/{folder}` |
| Profile (after login) | `clinicID`, `userID`, `languageId`, `oemID` |

Setup defaults: `subdomain=dev`, `folder=zoom`.

`openPickerInNative=true` tells the web app **not** to open `<input type="file">`. Instead it must use the native picker bridge:

- photos → type **4** → `window.onNativeImagePicked`
- video → type **5** → `window.onNativeVideoPicked`
- documents → type **6** → `window.onNativeFilePicked`

That avoids the iOS WKWebView freeze when Limited Photos access dismisses the system picker without firing `change` / `cancel`.

### Visit Doctor

`AppDestinations.visitDoctorUrl(config, profile, flags)`

Always included:

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &fromWebView=android
  &openPickerInNative=true
```

`protocolName` is **not** added.

Optional checkboxes on the home screen (appended only when selected):

| Checkbox | Appended when checked |
|----------|------------------------|
| `dependent=true` | `&dependent=true` |
| `ignoreLocationCheck=true` | `&ignoreLocationCheck=true` |

`disableCamera` and `forWR` are hidden for now and are **not** added to the URL.

### Example

Defaults `subdomain=dev`, `folder=zoom`, and profile `clinicID=1000254`, `userID=0b4a…`, `languageId=1`, `oemID=100`.

**Always:**
```
https://dev.geniemd.net/zoom/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&fromWebView=android&openPickerInNative=true
```

**Optional flags checked:**
```
https://dev.geniemd.net/zoom/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&fromWebView=android&openPickerInNative=true&dependent=true&ignoreLocationCheck=true
```

---

## Configuring for production / other environments

Update URL building in `AppDestinations.kt` (and Setup defaults in `strings.xml` if needed).

### Domain and folder

On first launch (Setup screen), or by changing defaults:

| Field | Sample (current) | Production example |
|-------|------------------|--------------------|
| Subdomain | `dev` | your prod subdomain (e.g. `www`, `app`, clinic code) |
| Folder | `zoom` | your prod folder (e.g. `zoom`, `apps`) |

Resulting base: `https://{subdomain}.geniemd.net/{folder}`

Defaults live in `res/values/strings.xml`:

```xml
<string name="default_subdomain">dev</string>
<string name="default_folder">zoom</string>
```

Users can also enter production values on the Setup screen; they are saved in SharedPreferences.

### Optional checkboxes

Home-screen checkboxes append these only when selected:

- `dependent=true`
- `ignoreLocationCheck=true`

`disableCamera` and `forWR` are hidden for now and are **not** added to the URL.

### `openPickerInNative=true`

Always appended on **Visit Doctor**. The web page must use the native picker bridge instead of a file input:

| Need | Send | Native calls |
|------|------|----------------|
| Photo | type `4` | `window.onNativeImagePicked` |
| Video | type `5` | `window.onNativeVideoPicked` |
| Document | type `6` | `window.onNativeFilePicked` |

Types 4, 5, and 6 are separate events. Do not answer a video or document request on `onNativeImagePicked`.

### Android vs iOS — `fromWebView`

| Platform | Query value |
|----------|-------------|
| Android (this app) | `fromWebView=android` |
| iOS | `fromWebView=ios` |

For an iOS WebView host, use the **same URL shapes** and only change:

```
fromWebView=android  →  fromWebView=ios
```

Apply that change on the Visit Doctor link. The rest of the path and query params stay the same.

An iOS host app lives at the repo root in `ios/WebBridge.xcodeproj`. It uses `fromWebView=ios`. See `../ios/README.md`.

---

## WebView native bridge

The WebView injects a JavaScript interface named **`NativeApp`**. The web app may also call `window.callNative(type, data)`, which forwards to the same handler.

```javascript
NativeApp.callback(JSON.stringify({ type: number, data: { ... } }));
// or
window.callNative(type, data);
```

Native handler: `BrowserBridge.callback(json)` in `BrowserBridge.kt` (iOS: `BrowserBridge.handle` in `BrowserBridge.swift`).

Must match PTX `bridge-action.constant.ts`.

| type | Meaning | Web → native | Native → web |
|------|---------|--------------|--------------|
| 1 | Waiting room | `{ url, success, openInBrowser }` | — |
| 2 | Close WebView | `{ success, close }` | — |
| 3 | Open schedule link | `{ url, success, openInBrowser }` | — |
| 4 | Photo picker | `{ accept: "image/*", source, multiple }` | `window.onNativeImagePicked` |
| **5** **(new)** | Video picker | `{ accept: "video/*", source: "photoLibrary", multiple: false }` | `window.onNativeVideoPicked` |
| **6** **(new)** | Document picker | `{ accept: "*/*", source: "files", multiple: false }` | `window.onNativeFilePicked` |
| **7** **(new)** | Open a URL | `{ url, success, openInBrowser, target }` | — |
| **8** **(new)** | Current location | `{ enableHighAccuracy, timeout }` | `window.onNativeLocation` |

Native picker and location callbacks always pass a **JSON string**, not an object:

```javascript
window.onNativeImagePicked(JSON.stringify({ ... }))
window.onNativeVideoPicked(JSON.stringify({ ... }))
window.onNativeFilePicked(JSON.stringify({ ... }))
window.onNativeLocation(JSON.stringify({ ... }))
```

Register the matching `window.onNative*` handler **before** sending the type.

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

#### Type `4` — Open native image picker **(new)**

Use this when the URL has `openPickerInNative=true`. Do **not** open `<input type="file">`.

**Web → native (send):**

```json
{
  "type": 4,
  "data": {
    "accept": "image/*",
    "source": "camera-or-library",
    "multiple": false
  }
}
```

| Field | Required | Behavior |
|-------|----------|----------|
| `accept` | no | Logged only; native always picks images |
| `source` | no | Logged only; native always shows **Take Photo** and **Photo Library** |
| `multiple` | no | `true` allows more than one library photo. Camera always returns one file |

Native presents a chooser: **Take Photo** (camera) or **Photo Library**. Cancel on the sheet, camera, or library returns a cancelled payload.

**Native → web (receive):**

Native calls a global function. The argument is a **JSON string** (not an object):

```javascript
window.onNativeImagePicked(jsonString)
```

Success:

```json
{
  "cancelled": false,
  "success": true,
  "files": [
    {
      "mimeType": "image/jpeg",
      "fileName": "native-photo.jpg",
      "dataUrl": "data:image/jpeg;base64,/9j/4AAQ..."
    }
  ]
}
```

Cancel / no file:

```json
{
  "cancelled": true,
  "success": false,
  "files": []
}
```

Web should register the handler **before** sending type 4:

```javascript
window.onNativeImagePicked = function (jsonString) {
  var result = typeof jsonString === "string" ? JSON.parse(jsonString) : jsonString;
  if (!result.success || result.cancelled || !result.files || !result.files.length) {
    return; // user cancelled
  }
  var files = result.files.map(function (item) {
    var comma = item.dataUrl.indexOf(",");
    var b64 = item.dataUrl.slice(comma + 1);
    var binary = atob(b64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return new File([bytes], item.fileName || "native-photo.jpg", {
      type: item.mimeType || "image/jpeg"
    });
  });
  // attach `files` to the same upload path as a normal file input
};

sendToNative(4, { accept: "image/*", multiple: false });
```

Android and iOS use the same send/receive shape.

#### Type `5` — Open native video picker **(new)**

One video from the library. Native answers on `window.onNativeVideoPicked`, **not** `onNativeImagePicked`.

**Web → native (send):**

```json
{
  "type": 5,
  "data": {
    "accept": "video/*",
    "source": "photoLibrary",
    "multiple": false
  }
}
```

**Native → web (receive):**

```javascript
window.onNativeVideoPicked(jsonString)
```

Success:

```json
{
  "cancelled": false,
  "success": true,
  "files": [
    {
      "mimeType": "video/mp4",
      "fileName": "native-video.mp4",
      "dataUrl": "data:video/mp4;base64,AAAA..."
    }
  ]
}
```

Cancel / no file: `{ "cancelled": true, "success": false, "files": [] }`

#### Type `6` — Open native document picker **(new)**

One file of any type (medical records). Native answers on `window.onNativeFilePicked`.

**Web → native (send):**

```json
{
  "type": 6,
  "data": {
    "accept": "*/*",
    "source": "files",
    "multiple": false
  }
}
```

**Native → web (receive):**

```javascript
window.onNativeFilePicked(jsonString)
```

Success:

```json
{
  "cancelled": false,
  "success": true,
  "files": [
    {
      "mimeType": "application/pdf",
      "fileName": "record.pdf",
      "dataUrl": "data:application/pdf;base64,JVBERi0..."
    }
  ]
}
```

Cancel / no file: `{ "cancelled": true, "success": false, "files": [] }`

#### Type `7` — Open a URL **(new)**

Used by `openWindow` in the web app. Does **not** close the WebView (unlike types 1 and 3).

**Web → native (send):**

```json
{
  "type": 7,
  "data": {
    "url": "https://example.com",
    "success": true,
    "openInBrowser": true,
    "target": "_blank"
  }
}
```

| Field | Behavior |
|-------|----------|
| `target: "_blank"` or `openInBrowser: true` | Open `url` in the system browser; keep the WebView open |
| `target: "_self"` | Load `url` inside the same WebView |

#### Type `8` — Current location **(new)**

**Web → native (send):**

```json
{
  "type": 8,
  "data": {
    "enableHighAccuracy": false,
    "timeout": 30000
  }
}
```

**Native → web (receive):**

```javascript
window.onNativeLocation(jsonString)
```

Granted:

```json
{
  "success": true,
  "latitude": 37.77,
  "longitude": -122.42
}
```

Denied / unavailable / timeout (`code` matches `GeolocationPositionError`):

```json
{
  "success": false,
  "code": 1
}
```

| `code` | Meaning |
|--------|---------|
| `1` | Permission denied |
| `2` | Position unavailable |
| `3` | Timed out |

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

// Open native camera / photo library (type 4)
sendToNative(4, { accept: "image/*", multiple: false });

// Open native video library (type 5)
sendToNative(5, { accept: "video/*", source: "photoLibrary", multiple: false });

// Open native document picker (type 6)
sendToNative(6, { accept: "*/*", source: "files", multiple: false });

// Open a URL without closing the WebView (type 7)
sendToNative(7, { url: "https://example.com", success: true, openInBrowser: true, target: "_blank" });

// Current location (type 8)
sendToNative(8, { enableHighAccuracy: false, timeout: 30000 });
```

Always check `window.NativeApp` so the same page can run in a normal browser without crashing.

### Security notes

- Only expose a narrow callback API (types 1–8).
- Validate URLs (`http` / `https` with a host) before opening.
- Prefer loading trusted origins only.
- Keep ProGuard rules for `@JavascriptInterface` methods if minify is enabled.

---

## App flow (context)

```
Launcher → Setup (first time) → Login → Home (Visit Doctor + Logout) → WebView
                                      ↑______________________|
                                         type 2 close / logout
```

- **Setup:** subdomain + folder (defaults `dev` / `zoom`), saved in SharedPreferences  
- **Login:** ValidateLogin → Profile → stores `userID`, `clinicID`, `languageId`, `oemID`  
- **Home:** Visit Doctor + Logout; optional query checkboxes; opens `WebViewActivity`  
- **Logout:** clears session only; config remains  

---

## Key files

| File | Purpose |
|------|---------|
| `AppDestinations.kt` | Constructs the three WebView URLs |
| `BrowserBridge.kt` | Native bridge (`NativeApp.callback`) types 1–8 |
| `WebViewActivity.kt` | Full-screen WebView host + native camera / photo / video / file pickers |
| `NativeLocationHelper.kt` | Type 8 location (`window.onNativeLocation`) |
| `MainActivity.kt` | Home buttons that open each URL |
| `data/AppPreferences.kt` | Cached config + session |
| `network/GenieMdApi.kt` | Login + profile APIs |

---

## Logcat

Filter tag: **`WebViewBridge`**

Useful messages: URL loads, bridge callbacks, browser launch, permission / file-chooser events.



for forwading local link
adb reverse tcp:4200 tcp:4200
adb reverse tcp:4201 tcp:4201