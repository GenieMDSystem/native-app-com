# iOS WebBridge

SwiftUI + WKWebView host that mirrors the Android app (`fromWebView=ios`).

## Run

1. Install **Xcode**
2. From the repo root, open `ios/WebBridge.xcodeproj`
3. Select an iPhone simulator or a signed device
4. Set your Development Team in Signing & Capabilities
5. Run (⌘R)

Flow: Splash → Setup (subdomain + folder) → Login → Home → WebView.

Home has a **Live ⇄ Local** toggle in DEBUG builds only. Release always uses live hosts.

Home also has a **Legacy WebView** toggle to reproduce the photo-picker hang vs the current `BridgeWebView`.

---

## Visit Doctor URL

Same shape as Android. Only `fromWebView` differs (`ios` vs `android`).

Setup defaults: `subdomain=dev`, `folder=zoom`.

Home UI is **Visit Doctor** plus **Logout**. Optional query flags are toggles.

Home also has **Shrink viewport when keyboard opens** (not a URL param). It is **not required** and defaults **off**: when the keyboard opens, the WebView does **not** shrink (keyboard overlays the page). Check the box only if you want WKWebView height to shrink so the layout viewport sits above the keyboard.

Always included (`protocolName` is **not** added):

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &fromWebView=ios
  &openPickerInNative=true
```

**`{clinicID}` in the path**

- Single clinic: `{clinicID}` is the profile `clinicID`.
- Multi-clinic: `{clinicID}` is the **selected** clinic id (not the profile clinic).

### Multi-clinic

When the user is in a multi-clinic setup, also send these **query params**:

| Query param | Value |
|-------------|--------|
| `multiClinic` | `true` |
| `masterClinic` | profile `clinicID` (same value that used to go in the path `{clinicID}`) |

Path `{clinicID}` = selected clinic id.

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{selectedClinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &fromWebView=ios
  &openPickerInNative=true
  &multiClinic=true
  &masterClinic={profileClinicID}
```

Optional checkboxes (appended only when selected):

- `dependent=true`
- `ignoreLocationCheck=true`

`disableCamera` and `forWR` are hidden for now and are **not** added to the URL.

`openPickerInNative=true` tells the web app **not** to open `<input type="file">`. Use native types 4 / 5 / 6 instead.

Keyboard shrink is **not** mandatory. Leave **Shrink viewport when keyboard opens** unchecked (default) so the keyboard overlays the WebView.

---

## Native bridge (types 1–8)

Same contract as Android. Web calls `NativeApp.callback(...)` or `window.callNative(type, data)`.

Must match PTX `bridge-action.constant.ts`.

| type | Meaning | Web → native | Native → web |
|------|---------|--------------|--------------|
| 1 | Waiting room | `{ url, success, openInBrowser }` | — (opens browser then closes WebView) |
| 2 | Close WebView | `{ success, close }` | — |
| 3 | Open schedule link | `{ url, success, openInBrowser }` | — (same as type 1) |
| 4 | Photo picker | `{ accept: "image/*", source, multiple }` | `window.onNativeImagePicked` |
| **5** **(new)** | Video picker | `{ accept: "video/*", source, multiple: false }` | `window.onNativeVideoPicked` (Record Video / Video Library / Choose File) |
| **6** **(new)** | Document picker | `{ accept: "*/*", source: "files", multiple: false }` | `window.onNativeFilePicked` |
| **7** **(new)** | Open a URL | `{ url, success, openInBrowser, target }` | — http(s): `_blank` = Safari, `_self` = same WebView. `tel:` / `mailto:` / `sms:` = system apps. Does **not** close. |
| **8** **(new)** | Current location | `{ enableHighAccuracy, timeout }` | `window.onNativeLocation` |

Types 4, 5, and 6 are separate. Do not answer a video or document request on `onNativeImagePicked`.

Native always calls the page with a **JSON string**:

```javascript
window.onNativeImagePicked(JSON.stringify({ ... }))
window.onNativeVideoPicked(JSON.stringify({ ... }))
window.onNativeFilePicked(JSON.stringify({ ... }))
window.onNativeLocation(JSON.stringify({ ... }))
```

### Type 4 — Photo

**Send:**

```json
{ "type": 4, "data": { "accept": "image/*", "source": "photoLibrary", "multiple": false } }
```

`multiple: true` allows more than one library photo. Camera always returns one file.

**Receive** (`window.onNativeImagePicked`):

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

Cancel: `{ "cancelled": true, "success": false, "files": [] }`

### Type 5 — Video **(new)**

Native presents a chooser (same idea as type 4 photos). One file is returned on `window.onNativeVideoPicked`.

| Chooser option | Source |
|----------------|--------|
| **Record Video** | Device camera (camera + microphone permission) |
| **Video Library** | Photos picker, videos only |
| **Choose File** | Files picker, video types |

Cancel on the sheet, camera, library, or file picker returns a cancelled payload. `accept` / `source` / `multiple` are logged only; video always returns one file.

**Send:**

```json
{ "type": 5, "data": { "accept": "video/*", "source": "camera-or-library", "multiple": false } }
```

**Receive** (`window.onNativeVideoPicked`):

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

### Type 6 — Document **(new)**

**Send:**

```json
{ "type": 6, "data": { "accept": "*/*", "source": "files", "multiple": false } }
```

**Receive** (`window.onNativeFilePicked`):

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

### Type 7 — Open a URL **(new)**

Does **not** close the WebView.

**http(s):**

```json
{ "type": 7, "data": { "url": "https://example.com", "success": true, "openInBrowser": true, "target": "_blank" } }
```

- `target: "_blank"` or `openInBrowser: true` → open in Safari
- `target: "_self"` → load inside the same WebView

**`tel:` / `mailto:` / `sms:` (Call 911, mail, SMS):**

```json
{ "type": 7, "data": { "url": "tel:911", "success": true } }
```

```json
{ "type": 7, "data": { "url": "mailto:support@example.com", "success": true } }
```

```json
{ "type": 7, "data": { "url": "sms:+15555550100", "success": true } }
```

| Scheme | Opens |
|--------|--------|
| `tel:` | System Phone / dialer (never load in WKWebView) |
| `mailto:` | System Mail |
| `sms:` | System Messages |

Same schemes also work on types **1** and **3**. If the page uses `<a href="tel:…">` (or mailto/sms), native intercepts navigation and opens the system app. App-scheme URLs leave the WebView open.

### Type 8 — Location **(new)**

**Send:**

```json
{ "type": 8, "data": { "enableHighAccuracy": false, "timeout": 30000 } }
```

**Receive** (`window.onNativeLocation`):

Granted: `{ "success": true, "latitude": 37.77, "longitude": -122.42 }`

Failed: `{ "success": false, "code": 1 }`

| `code` | Meaning |
|--------|---------|
| `1` | Permission denied |
| `2` | Position unavailable |
| `3` | Timed out |

Register the matching `window.onNative*` handler **before** sending the type. Parse the JSON string, convert each picker `dataUrl` to a `File`, and upload as usual.

See `WebViewBrowserBridge/README.md` for types 1–3 and a full JS helper example.

---

## Native logs

Filter Xcode console for **`[WebViewBridge]`**. Type 1 (waiting room), type 3 (schedule link), and type 7 print the received URL.
