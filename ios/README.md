# iOS WebBridge

SwiftUI + WKWebView host that mirrors the Android app (`fromWebView=ios`).

Full Android detail (both branches + bridge payloads):  
[`../WebViewBrowserBridge/README.md`](../WebViewBrowserBridge/README.md)

## Run

1. Install **Xcode**
2. Open `ios/WebBridge.xcodeproj` from the repo root
3. Select simulator or signed device
4. Set Development Team in Signing & Capabilities
5. Run (⌘R)

Flow: Splash → Setup → Login → Home → WebView.

DEBUG: **Live ⇄ Local** toggle. Release always uses live hosts.  
**Legacy WebView** toggle reproduces the photo-picker hang vs current `BridgeWebView`.

---

## Shared links by native branch

| Branch | Home links | Notes |
|--------|------------|-------|
| `v2-splash-login-page` | Visit Doctor, Schedule Visit, **Schedules List** (`patient-schedule`) | Full params including `protocolName`, `forWR`, `showCQ`, `disableCamera` |
| `visit-doctor-optional-params` | Visit Doctor only | Minimal always-on params; optional checkboxes; no `protocolName` / `forWR` / `showCQ` / `disableCamera` by default |

Only `fromWebView` differs (`ios` vs `android`).

### Branch A — `v2-splash-login-page`

#### Visit Doctor Now

```
{assessmentBase}/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20TeleConsultation
  &dependent=true
  &fromWebView=ios
  &ignoreLocationCheck=true
  &disableCamera=true
  &openPickerInNative=true
  &forWR=true
  &showCQ=true
```

#### Schedule Visit Now

```
{assessmentBase}/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20Scheudle%20a%20TeleConsultation
  &dependent=true
  &fromWebView=ios
  &ignoreLocationCheck=true
  &disableCamera=true
  &openPickerInNative=true
```

#### Schedules List (`patient-schedule`) — extra RPM link

```
{rpmBase}/#/webview/{clinicID}/{userID}/patient-schedule
  ?fromWebView=ios
```

Only query param: `fromWebView`. Live base: `https://{subdomain}.geniemd.net/{folder}/rpm`. Local: `http://localhost:4200/rpm`.

| Param | Visit Doctor | Schedule Visit | Schedules List |
|-------|--------------|----------------|----------------|
| `protocolName` | yes | yes | no |
| `dependent` | yes | yes | no |
| `fromWebView` | yes | yes | yes |
| `ignoreLocationCheck` | yes | yes | no |
| `disableCamera` | yes | yes | no |
| `openPickerInNative` | yes | yes | no |
| `forWR` / `showCQ` | yes | no | no |

### Branch B — `visit-doctor-optional-params`

Always:

```
…/consent/{userID}?patientLanguageID=…&patientOEMID=…&fromWebView=ios&openPickerInNative=true
```

Optional checkboxes: `dependent=true`, `ignoreLocationCheck=true`.  
Multi-clinic: path = selected clinic + `multiClinic=true&masterClinic={profileClinicID}`.  
Not added: `protocolName`, `disableCamera`, `forWR`, `showCQ`.  
No Schedule Visit / Schedules List on this branch home.

`showCQ=true` (v2 Visit Doctor) → PTX forwards so RMX shows the connect queue page.

---

## Native bridge (types 1–8)

Same contract as Android. Web: `NativeApp.callback(...)` or `window.callNative(type, data)`.

Must match PTX `bridge-action.constant.ts`.

| type | Meaning | Web → native | Native → web |
|------|---------|--------------|--------------|
| 1 | Waiting room | `{ url, success, openInBrowser }` | — |
| 2 | Close WebView | `{ success, close }` | — |
| 3 | Open schedule link | `{ url, success, openInBrowser }` | — |
| 4 | Photo picker | `{ accept: "image/*", source, multiple }` | `window.onNativeImagePicked` |
| 5 | Video picker | `{ accept: "video/*", source, multiple: false }` | `window.onNativeVideoPicked` |
| 6 | Document picker | `{ accept: "*/*", source: "files", multiple: false }` | `window.onNativeFilePicked` |
| 7 | Open a URL | `{ url, success, openInBrowser, target }` — http(s) or `tel:` / `mailto:` / `sms:` | — (does not close) |
| 8 | Current location | `{ enableHighAccuracy, timeout }` | `window.onNativeLocation` |

Types 4–6 are separate. Callbacks are **JSON strings**.

### Type 4 — Photo

```json
{ "type": 4, "data": { "accept": "image/*", "source": "camera-or-library", "multiple": false } }
```

Success: `{ "cancelled": false, "success": true, "files": [{ "mimeType", "fileName", "dataUrl" }] }`  
Cancel: `{ "cancelled": true, "success": false, "files": [] }`

### Type 5 — Video

Chooser: Record Video / Video Library / Choose File.

```json
{ "type": 5, "data": { "accept": "video/*", "source": "camera-or-library", "multiple": false } }
```

→ `window.onNativeVideoPicked`

### Type 6 — Document

```json
{ "type": 6, "data": { "accept": "*/*", "source": "files", "multiple": false } }
```

→ `window.onNativeFilePicked`

### Type 7 — Open a URL

Does **not** close the WebView.

```json
{ "type": 7, "data": { "url": "https://example.com", "success": true, "openInBrowser": true, "target": "_blank" } }
```

```json
{ "type": 7, "data": { "url": "tel:911", "success": true } }
```

- `_blank` / `openInBrowser: true` → Safari  
- `_self` → same WebView  
- `tel:` / `mailto:` / `sms:` → system apps

### Type 8 — Location

```json
{ "type": 8, "data": { "enableHighAccuracy": false, "timeout": 30000 } }
```

Granted: `{ "success": true, "latitude", "longitude" }`  
Failed: `{ "success": false, "code": 1|2|3 }`

Register `window.onNative*` **before** sending. See Android README for types 1–3 and full JS helper.

---

## Native logs

Filter Xcode console for **`[WebViewBridge]`**.
