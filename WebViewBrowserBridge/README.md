# WebViewBrowserBridge

Kotlin Android app that:

1. Saves environment config (subdomain + folder) and user session
2. Builds WebView URLs from that data
3. Hosts those pages in a native WebView with a **JavaScript bridge** (`NativeApp`)

This README matches the PTX host-link / bridge docs and covers both native branches:

- `v2-splash-login-page`
- `visit-doctor-optional-params`

| File | Role |
|------|------|
| `AppDestinations.kt` | Builds Visit Doctor / Schedule Visit / Schedules List URLs |
| `BrowserBridge.kt` | `NativeApp.callback` types 1–8 |
| `WebViewActivity.kt` | Full-screen WebView + native pickers |
| `MainActivity.kt` | Home buttons |
| `NativeLocationHelper.kt` | Type 8 location |

Must stay aligned with PTX:

- `assessment-query-params.service.ts`
- `bridge-action.constant.ts`
- `utility.ts` (`callNativeBridge`, `buildWaitingRoomConnectUrl`)

---

## Local hosts

| App | Dev server | Emulator forward |
|-----|------------|------------------|
| Assessment (PTX) | `http://localhost:4201` | `adb reverse tcp:4201 tcp:4201` |
| RPM (schedules + WR connect) | `http://localhost:4200/rpm` | `adb reverse tcp:4200 tcp:4200` |

```bash
adb reverse tcp:4200 tcp:4200
adb reverse tcp:4201 tcp:4201
```

Setup defaults (current v2 sample): `subdomain=mhc`, `folder=apps2` → `https://mhc.geniemd.net/apps2`.

```xml
<string name="default_subdomain">mhc</string>
<string name="default_folder">apps2</string>
```

---

## Shared links by native branch

| Branch | Home links | Notes |
|--------|------------|-------|
| `v2-splash-login-page` | **Visit Doctor Now**, **Schedule Visit Now**, **Schedules List** (`patient-schedule`) | Full assessment query set including `protocolName`, `forWR`, `showCQ`, `disableCamera` |
| `visit-doctor-optional-params` | **Visit Doctor** only (+ Logout) | Minimal always-on params; optional flags via home checkboxes; **no** `protocolName` / `forWR` / `showCQ` / `disableCamera` by default |

### Path params (assessment links)

| Path segment | Description |
|--------------|-------------|
| `{clinicID}` | Clinic for the protocol route. Single-clinic: profile clinic id. Multi-clinic: **selected** clinic id (not the profile/master clinic). |
| `consent` | Starts at the consent screen. |
| `{userID}` | Logged-in patient / profile user id from native login. |

### Path params (Schedules List / RPM)

| Path segment | Description |
|--------------|-------------|
| `{clinicID}` | Clinic id for the patient schedule webview |
| `{userID}` | Logged-in user id |
| `patient-schedule` | RPM schedules list route |

---

## Branch A — `v2-splash-login-page`

Builders: `visitDoctorUrl`, `scheduleVisitUrl`, `schedulesListUrl` in `AppDestinations.kt`.

### 1. Visit Doctor Now (waiting room / teleconsult)

```
{assessmentBase}/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocationCheck=true
  &disableCamera=true
  &openPickerInNative=true
  &forWR=true
  &showCQ=true
```

### 2. Schedule Visit Now

```
{assessmentBase}/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &protocolName=Revamp%20Scheudle%20a%20TeleConsultation
  &dependent=true
  &fromWebView=android
  &ignoreLocationCheck=true
  &disableCamera=true
  &openPickerInNative=true
```

No `forWR` / `showCQ` on Schedule Visit.

### 3. Schedules List (`patient-schedule`) — extra RPM link

Opens the RPM patient schedule list (not an assessment protocol).

```
{rpmBase}/#/webview/{clinicID}/{userID}/patient-schedule
  ?fromWebView=android
```

| | Live | Local |
|-|------|-------|
| Base | `https://{subdomain}.geniemd.net/{folder}/rpm` | `http://localhost:4200/rpm` |
| Full example | `https://mhc.geniemd.net/apps2/rpm/#/webview/1000254/0b4a…/patient-schedule?fromWebView=android` | `http://localhost:4200/rpm/#/webview/…/patient-schedule?fromWebView=android` |

Only query param: **`fromWebView`**. No `protocolName`, `forWR`, `showCQ`, `openPickerInNative`, etc.

| Param on v2 | Visit Doctor | Schedule Visit | Schedules List |
|-------------|--------------|----------------|----------------|
| `patientLanguageID` | yes | yes | no |
| `patientOEMID` | yes | yes | no |
| `protocolName` | yes | yes | no |
| `dependent` | yes (always) | yes (always) | no |
| `fromWebView` | yes | yes | yes |
| `ignoreLocationCheck` | yes (always) | yes (always) | no |
| `disableCamera` | yes | yes | no |
| `openPickerInNative` | yes | yes | no |
| `forWR` | yes | no | no |
| `showCQ` | yes | no | no |

**Examples** (`subdomain=mhc`, `folder=apps2`, `clinicID=1000254`, `languageId=1`, `oemID=100`):

**Visit Doctor:**
```
https://mhc.geniemd.net/apps2/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&protocolName=Revamp%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true&openPickerInNative=true&forWR=true&showCQ=true
```

**Schedule Visit:**
```
https://mhc.geniemd.net/apps2/assessment/#/protocol/1000254/consent/0b4a…?patientLanguageID=1&patientOEMID=100&protocolName=Revamp%20Scheudle%20a%20TeleConsultation&dependent=true&fromWebView=android&ignoreLocationCheck=true&disableCamera=true&openPickerInNative=true
```

**Schedules List:**
```
https://mhc.geniemd.net/apps2/rpm/#/webview/1000254/0b4a…/patient-schedule?fromWebView=android
```

---

## Branch B — `visit-doctor-optional-params`

Home UI: **Visit Doctor** + **Logout**. Optional query flags are **checkboxes** (appended only when checked).

### Visit Doctor — always included

```
{assessmentBase}/#/protocol/{clinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &fromWebView=android
  &openPickerInNative=true
```

- `protocolName` is **not** added (protocol comes from clinic / route defaults).
- `disableCamera`, `forWR`, and `showCQ` are **hidden** on this branch and are **not** added to the URL.
- This branch does **not** ship Schedule Visit or Schedules List home buttons.

### Optional checkboxes (appended only when selected)

| Checkbox | Appended when checked |
|----------|------------------------|
| Dependent | `&dependent=true` |
| Ignore location check | `&ignoreLocationCheck=true` |

**Always (no optional flags):**

```
…/consent/{userID}?patientLanguageID=1&patientOEMID=100&fromWebView=android&openPickerInNative=true
```

**Optional flags checked:**

```
…/consent/{userID}?patientLanguageID=1&patientOEMID=100&fromWebView=android&openPickerInNative=true&dependent=true&ignoreLocationCheck=true
```

### Multi-clinic

When multi-clinic:

- Path `{clinicID}` = **selected** clinic id
- Query: `multiClinic=true&masterClinic={profileClinicID}`

```
…/#/protocol/{selectedClinicID}/consent/{userID}
  ?patientLanguageID={languageId}
  &patientOEMID={oemID}
  &fromWebView=android
  &openPickerInNative=true
  &multiClinic=true
  &masterClinic={profileClinicID}
```

Do **not** add `multiClinic` / `masterClinic` for a single-clinic user.

### WebView option (not a URL param)

| Checkbox | Default | When unchecked | When checked |
|----------|---------|----------------|--------------|
| Shrink viewport when keyboard opens | **off** | Keyboard overlays the WebView | WebView height shrinks with the IME |

Cached in native prefs and passed into `WebViewActivity` — not part of the PTX query string.

| Param on visit-doctor branch | Always | Optional checkbox | Not used |
|------------------------------|--------|-------------------|----------|
| `patientLanguageID` | yes | | |
| `patientOEMID` | yes | | |
| `fromWebView` | yes | | |
| `openPickerInNative` | yes | | |
| `dependent` | | yes | |
| `ignoreLocationCheck` | | yes | |
| `multiClinic` / `masterClinic` | when multi-clinic | | |
| `protocolName` | | | not added |
| `disableCamera` | | | not added |
| `forWR` | | | not added |
| `showCQ` | | | not added |

---

## Query params — detailed reference

##### `patientLanguageID`

- **Type:** string number (e.g. `1`)
- **Source:** native profile `languageId`
- **Purpose:** Selects the Language API locale for assessment copy.
- **Branches:** always on assessment links (both branches). Not on Schedules List.

##### `patientOEMID`

- **Type:** string number (e.g. `100`, `110`)
- **Source:** native profile `oemID`
- **Purpose:** OEM / brand context for clinic config and localization.
- **Branches:** always on assessment links (both branches). Not on Schedules List.

##### `protocolName`

- **Type:** URL-encoded protocol title
- **Examples:** `Revamp%20TeleConsultation`, `Revamp%20Scheudle%20a%20TeleConsultation`
- **Purpose:** Tells PTX which protocol definition to load. Must match GenieMD / Protocol Designer exactly.
- **Branches:** **v2 only** (Visit + Schedule). **Not** on `visit-doctor-optional-params` or Schedules List.
- **Note:** Spaces must be `%20`. Change in `AppDestinations.kt` for production names.

##### `dependent`

- **Type:** `true` \| `1` \| `yes` → dependent flow
- **Purpose:** Caregiver-for-another-patient assessment instead of self.
- **Branches:** always on **v2** Visit/Schedule; optional checkbox on **visit-doctor-optional-params**

##### `fromWebView`

- **Type:** `android` (this app) \| `ios` (iOS host)
- **Purpose:** Marks the session as inside a native WebView. When set:
  - External links go through the native bridge
  - Waiting-room / schedule open uses bridge types 1 / 3
  - With `disableCamera` + `openPickerInNative` enables native media pickers
- **Branches:** always on all links including **Schedules List**

##### `ignoreLocationCheck`

- **Type:** `true`
- **Purpose:** Skips the web geolocation gate (native type 8 can still provide location).
- **Branches:** always on **v2** Visit/Schedule; optional checkbox on **visit-doctor-optional-params**

##### `disableCamera`

- **Type:** `true`
- **Purpose:** Hides in-page “Take Photo” / camera capture UI; prefer file / native picker.
- **Branches:** **v2** Visit + Schedule only. Hidden on **visit-doctor-optional-params**. Not on Schedules List.

##### `openPickerInNative`

- **Type:** `true`
- **Purpose:** Web must **not** open `<input type="file">`. Use bridge types **4 / 5 / 6**.
- **Required for native image library in PTX:** `fromWebView` + `disableCamera` + `openPickerInNative`
- **Branches:** always on assessment links (both branches). Not on Schedules List.
- **Why:** Avoids iOS WKWebView freezes with Limited Photos access.

##### `forWR`

- **Type:** `true`
- **Purpose (for Waiting Room):**
  1. Forces waiting-room encounter type/status on submit
  2. After provider notify, opens the waiting-room connect URL (bridge type 1)
- Does **not** create `Meetings/Create` by itself.
- **Branches:** **v2 Visit Doctor only**

##### `showCQ`

- **Type:** `true`
- **Purpose (show Connect Queue):** PTX forwards `&showCQ=true` onto the WR connect URL so RMX shows the connect queue page (“Connecting to a Doctor”).
- **Branches:** **v2 Visit Doctor only**

##### `multiClinic` / `masterClinic`

- **`multiClinic=true`:** path clinic = selected clinic
- **`masterClinic={profileClinicID}`:** profile/master clinic id
- Documented on **visit-doctor-optional-params**; also valid if v2 sends them
- Do not send for single-clinic users

---

## Native bridge events — detailed reference

Web → native:

```javascript
window.callNative(type, data);
// or
NativeApp.callback(JSON.stringify({ type, data }));
```

Native handler: `BrowserBridge.callback(json)` in `BrowserBridge.kt`.

Must match PTX `bridge-action.constant.ts`.

| type | Constant | Meaning | Native → web |
|------|----------|---------|--------------|
| 1 | `WAITING_ROOM` | Open waiting-room connect URL | — |
| 2 | `SCHEDULE` | Close WebView / return home | — |
| 3 | `OPEN_SCHEDULE_LINK` | Open schedule URL | — |
| 4 | `OPEN_NATIVE_IMAGE_PICKER` | Photo picker | `window.onNativeImagePicked` |
| 5 | `OPEN_NATIVE_VIDEO_PICKER` | Video picker | `window.onNativeVideoPicked` |
| 6 | `OPEN_NATIVE_FILE_PICKER` | Document picker | `window.onNativeFilePicked` |
| 7 | `OPEN_EXTERNAL_LINK` | Open http(s) or `tel:` / `mailto:` / `sms:` | — (WebView stays open) |
| 8 | `GET_NATIVE_LOCATION` | Current GPS location | `window.onNativeLocation` |

Types **4 / 5 / 6** are separate. Never answer video/document on `onNativeImagePicked`.

Callbacks always pass a **JSON string**. Register the handler **before** calling native.

```javascript
window.onNativeImagePicked(JSON.stringify({ ... }))
window.onNativeVideoPicked(JSON.stringify({ ... }))
window.onNativeFilePicked(JSON.stringify({ ... }))
window.onNativeLocation(JSON.stringify({ ... }))
```

---

### Type `1` — Waiting room (`WAITING_ROOM`)

Used after provider notify when `forWR=true`. Opens the RPM connect URL (may include `showCQ=true`).

```json
{
  "type": 1,
  "data": {
    "url": "https://…/rpm/#/…/connect?type=video&status=waitingroom&showCQ=true",
    "success": true,
    "openInBrowser": true
  }
}
```

| Field | Description |
|-------|-------------|
| `url` | Full waiting-room connect URL |
| `success` | `false` → error toast only |
| `openInBrowser` | `true` → system browser, then close WebView → home. `false` → same WebView |

Also accepts `tel:` / `mailto:` / `sms:` (system app; WebView usually stays open).

---

### Type `2` — Close WebView (`SCHEDULE`)

```json
{ "type": 2, "data": { "success": true } }
```

or `{ "close": true }`. If either flag is true, close WebView → home.

---

### Type `3` — Open schedule link (`OPEN_SCHEDULE_LINK`)

Same open rules as type 1 (browser vs WebView, then home when opening browser).

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

---

### Type `4` — Native photo picker (`OPEN_NATIVE_IMAGE_PICKER`)

Use when `openPickerInNative=true`. Do **not** open `<input type="file">`.

**Send:**

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

| Field | Required | Description |
|-------|----------|-------------|
| `accept` | no | Logged; native always picks images |
| `source` | no | Logged; shows **Take Photo** + **Photo Library** |
| `multiple` | no | `true` allows multiple library photos; camera = one file |

**Receive:** `window.onNativeImagePicked(jsonString)`

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

Cancel: `{ "cancelled": true, "success": false, "files": [] }`

| Result field | Description |
|--------------|-------------|
| `cancelled` | User dismissed the picker |
| `success` | At least one usable file when `true` |
| `files[].mimeType` | e.g. `image/jpeg` |
| `files[].fileName` | Display / upload name |
| `files[].dataUrl` | Base64 data URL |

---

### Type `5` — Native video picker (`OPEN_NATIVE_VIDEO_PICKER`)

Answers on `window.onNativeVideoPicked` only.

| Chooser option | Source |
|----------------|--------|
| Record Video | Device camera (+ microphone) |
| Video Library | Photos picker, videos only |
| Choose File | Files picker, video types |

**Send:**

```json
{
  "type": 5,
  "data": {
    "accept": "video/*",
    "source": "camera-or-library",
    "multiple": false
  }
}
```

`multiple` ignored; always one video. Same `files[]` shape (`mimeType` e.g. `video/mp4`).

---

### Type `6` — Native document picker (`OPEN_NATIVE_FILE_PICKER`)

Medical records / any file → `window.onNativeFilePicked`.

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

Same `files[]` shape (`mimeType` e.g. `application/pdf`).

---

### Type `7` — Open a URL (`OPEN_EXTERNAL_LINK`)

Does **not** close the WebView (unlike types 1 / 3 for http browser opens).

**http(s):**

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

**App schemes:**

```json
{ "type": 7, "data": { "url": "tel:911", "success": true } }
```

```json
{ "type": 7, "data": { "url": "mailto:support@example.com", "success": true } }
```

```json
{ "type": 7, "data": { "url": "sms:+15555550100", "success": true } }
```

| Field / URL | Behavior |
|-------------|----------|
| `target: "_blank"` or `openInBrowser: true` | System browser; keep WebView open |
| `target: "_self"` | Load inside same WebView |
| `tel:` | System dialer (Call 911) |
| `mailto:` | System mail |
| `sms:` | System SMS |

`tel:` / `mailto:` / `sms:` also work on types 1 and 3. Intercept in-page `<a href="tel:…">` the same way.

---

### Type `8` — Current location (`GET_NATIVE_LOCATION`)

**Send:**

```json
{
  "type": 8,
  "data": {
    "enableHighAccuracy": false,
    "timeout": 30000
  }
}
```

| Field | Description |
|-------|-------------|
| `enableHighAccuracy` | Prefer GPS when `true` |
| `timeout` | ms before `code: 3` |

**Receive:** `window.onNativeLocation(jsonString)`

Granted: `{ "success": true, "latitude": 37.77, "longitude": -122.42 }`  
Failed: `{ "success": false, "code": 1 }` (`1` denied, `2` unavailable, `3` timeout)

---

## Example: calling native from the page

```javascript
function sendToNative(type, data) {
  if (window.NativeApp && window.NativeApp.callback) {
    window.NativeApp.callback(JSON.stringify({ type: type, data: data }));
  } else if (typeof window.callNative === "function") {
    window.callNative(type, data);
  } else {
    console.warn("Native bridge not available");
  }
}

sendToNative(2, { close: true });
sendToNative(1, { url: "https://example.com", success: true, openInBrowser: true });
sendToNative(4, { accept: "image/*", multiple: false });
sendToNative(5, { accept: "video/*", source: "camera-or-library", multiple: false });
sendToNative(6, { accept: "*/*", source: "files", multiple: false });
sendToNative(7, { url: "tel:911", success: true });
sendToNative(8, { enableHighAccuracy: false, timeout: 30000 });
```

Always guard for `NativeApp` / `callNative` so the same page can run in a desktop browser.

### Security notes

- Only expose types 1–8.
- Validate URLs (`http` / `https` with a host, or allowed app schemes) before opening.
- Prefer trusted origins only.
- Keep ProGuard rules for `@JavascriptInterface` if minify is enabled.

---

## App flow

```
Launcher → Setup (first time) → Login → Home → WebView
                                      ↑___________|
                                   type 2 close / logout
```

- **v2 home:** Visit Doctor / Schedule Visit / Schedules List  
- **visit-doctor home:** Visit Doctor + Logout (+ optional checkboxes)  
- **Logout:** clears session only; config remains  

---

## Logcat

Filter tag: **`WebViewBridge`**

Useful messages: URL loads, bridge callbacks, browser launch, permission / file-chooser events.

iOS mirror: [`../ios/README.md`](../ios/README.md) (`fromWebView=ios`).
