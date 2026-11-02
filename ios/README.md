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
| **5** **(new)** | Video picker | `{ accept: "video/*", source: "photoLibrary", multiple: false }` | `window.onNativeVideoPicked` |
| **6** **(new)** | Document picker | `{ accept: "*/*", source: "files", multiple: false }` | `window.onNativeFilePicked` |
| **7** **(new)** | Open a URL | `{ url, success, openInBrowser, target }` | — (`_blank` = Safari, `_self` = same WebView; does **not** close) |
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

**Send:**

```json
{ "type": 5, "data": { "accept": "video/*", "source": "photoLibrary", "multiple": false } }
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

```json
{ "type": 7, "data": { "url": "https://example.com", "success": true, "openInBrowser": true, "target": "_blank" } }
```

- `target: "_blank"` or `openInBrowser: true` → open in Safari
- `target: "_self"` → load inside the same WebView

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
