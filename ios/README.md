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

## New query params

Same flags as Android. Only `fromWebView` differs (`ios` vs `android`).

| Param | Value | Visit Doctor Now | Schedule Visit Now | Schedules List |
|-------|-------|------------------|--------------------|----------------|
| **`disableCamera`** **(new)** | `true` | yes | yes | no |
| **`forWR`** **(new)** | `true` | yes | no | no |
| **`openPickerInNative`** **(new)** | `true` | yes | yes | no |

### Visit Doctor Now

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20TeleConsultation
  &dependent=true
  &fromWebView=ios
  &ignoreLocationCheck=true
  &disableCamera=true          # NEW
  &openPickerInNative=true     # NEW
  &forWR=true                  # NEW — Visit Doctor only
```

### Schedule Visit Now

```
https://{subdomain}.geniemd.net/{folder}/assessment/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20Scheudle%20a%20TeleConsultation
  &dependent=true
  &fromWebView=ios
  &ignoreLocationCheck=true
  &disableCamera=true          # NEW
  &openPickerInNative=true     # NEW
```

### Schedules List

```
https://{subdomain}.geniemd.net/{folder}/rpm/#/webview/{clinicID}/{userID}/patient-schedule
  ?fromWebView=ios
```

No new query params.

---

## File picker bridge (type 4)

When `openPickerInNative=true`, the web page must **not** use `<input type="file">`. That WKWebView picker freezes the UI after Limited Photos dismiss.

### Web → native (send)

```javascript
NativeApp.callback(JSON.stringify({
  type: 4,
  data: { accept: "image/*", source: "camera-or-library", multiple: false }
}));
```

Native shows **Take Photo** / **Photo Library** (same as Android).

### Native → web (receive)

Native calls a global function. The argument is a **JSON string**:

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

Cancel:

```json
{
  "cancelled": true,
  "success": false,
  "files": []
}
```

Register `window.onNativeImagePicked` before sending type 4. Parse the string, convert each `dataUrl` to a `File`, then upload as usual.

See `WebViewBrowserBridge/README.md` for types 1–3 and a full JS example.

---

## Native logs

Filter Xcode console for **`[WebViewBridge]`**. Type 1 (waiting room) and type 3 (schedule link) print the received URL.
