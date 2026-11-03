import Foundation
import UIKit

// Callback types from JavaScript -> native. Must match PTX bridge-action.constant.ts.
// type 1 WAITING_ROOM: { type: 1, data: { url, success, openInBrowser } }
// type 2 SCHEDULE / CLOSE: { type: 2, data: { success: true } } or { close: true }
// type 3 OPEN_SCHEDULE_LINK: { type: 3, data: { url, success, openInBrowser } }
// type 4 OPEN_NATIVE_IMAGE_PICKER: { type: 4, data: { accept, source, multiple } }
//   Native answers with window.onNativeImagePicked(json).
// type 5 OPEN_NATIVE_VIDEO_PICKER: { type: 5, data: { accept: 'video/*', source, multiple } }
//   Native answers with window.onNativeVideoPicked(json).
// type 6 OPEN_NATIVE_FILE_PICKER: { type: 6, data: { accept: '*/*', source: 'files', multiple } }
//   Native answers with window.onNativeFilePicked(json).
// type 7 OPEN_EXTERNAL_LINK: { type: 7, data: { url, success, openInBrowser, target } }
// type 8 GET_NATIVE_LOCATION: { type: 8, data: { enableHighAccuracy, timeout } }
//   Native answers with window.onNativeLocation(json).
enum BridgeAction: Int {
    case waitingRoom = 1
    case schedule = 2
    case openScheduleLink = 3
    case openNativeImagePicker = 4
    case openNativeVideoPicker = 5
    case openNativeFilePicker = 6
    case openExternalLink = 7
    case getNativeLocation = 8
}

struct UrlBridgeData {
    let url: String
    let success: Bool
    let openInBrowser: Bool
    let target: String
}

struct ScheduleBridgeData {
    let success: Bool
    let close: Bool

    var shouldCloseWebView: Bool { success || close }
}

protocol BridgeCallbackHost: AnyObject {
    func loadUrlInWebView(_ url: String)
    func finishWithResult()
    func showBridgeMessage(_ message: String)
    func openNativeImagePicker(multiple: Bool)
    func openNativeVideoPicker()
    func openNativeFilePicker()
    func getNativeLocation(enableHighAccuracy: Bool, timeoutMs: Int)
}

/// Parses `NativeApp.callback(json)` payloads from the WebView.
enum BrowserBridge {
    static let interfaceName = "NativeApp"
    static let messageHandlerName = "NativeApp"
    private static let defaultLocationTimeoutMs = 30_000

    /// Injected so web pages can call `NativeApp.callback(...)` like on Android.
    static let injectionSource = """
    (function() {
      if (window.NativeApp && window.NativeApp.__iosBridge) { return; }
      window.NativeApp = {
        __iosBridge: true,
        callback: function(json) {
          try {
            var payload = (typeof json === 'string') ? json : JSON.stringify(json);
            window.webkit.messageHandlers.NativeApp.postMessage(payload);
          } catch (e) {
            console.warn('NativeApp bridge error', e);
          }
        }
      };
      window.callNative = function(type, data) {
        window.NativeApp.callback(JSON.stringify({ type: type, data: data }));
        return true;
      };
    })();
    """

    static func handle(json: String, host: BridgeCallbackHost) {
        print("[WebViewBridge] Native callback received: \(json)")
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = parseInt(root["type"])
        else {
            host.showBridgeMessage("Invalid callback JSON")
            return
        }

        guard let action = BridgeAction(rawValue: type) else {
            host.showBridgeMessage("Unknown bridge action: \(type)")
            return
        }

        guard let dataObj = root["data"] as? [String: Any] else {
            host.showBridgeMessage("Invalid bridge payload")
            return
        }

        switch action {
        case .waitingRoom, .openScheduleLink:
            handleUrlAction(action: action, payload: parseUrlData(dataObj), closeAfterBrowser: true, host: host)
        case .openExternalLink:
            handleUrlAction(action: action, payload: parseUrlData(dataObj), closeAfterBrowser: false, host: host)
        case .schedule:
            handleSchedule(parseScheduleData(dataObj), host: host)
        case .openNativeImagePicker:
            let multiple = parseBool(dataObj["multiple"])
            print("[WebViewBridge] OPEN_NATIVE_IMAGE_PICKER accept=\(dataObj["accept"] ?? "") source=\(dataObj["source"] ?? "") multiple=\(multiple)")
            DispatchQueue.main.async {
                host.openNativeImagePicker(multiple: multiple)
            }
        case .openNativeVideoPicker:
            print("[WebViewBridge] OPEN_NATIVE_VIDEO_PICKER accept=\(dataObj["accept"] ?? "") source=\(dataObj["source"] ?? "")")
            DispatchQueue.main.async {
                host.openNativeVideoPicker()
            }
        case .openNativeFilePicker:
            print("[WebViewBridge] OPEN_NATIVE_FILE_PICKER accept=\(dataObj["accept"] ?? "") source=\(dataObj["source"] ?? "")")
            DispatchQueue.main.async {
                host.openNativeFilePicker()
            }
        case .getNativeLocation:
            let enableHighAccuracy = parseBool(dataObj["enableHighAccuracy"])
            let timeoutMs = parseInt(dataObj["timeout"]) ?? defaultLocationTimeoutMs
            print("[WebViewBridge] GET_NATIVE_LOCATION enableHighAccuracy=\(enableHighAccuracy) timeout=\(timeoutMs)")
            DispatchQueue.main.async {
                host.getNativeLocation(enableHighAccuracy: enableHighAccuracy, timeoutMs: timeoutMs)
            }
        }
    }

    private static func handleUrlAction(
        action: BridgeAction,
        payload: UrlBridgeData,
        closeAfterBrowser: Bool,
        host: BridgeCallbackHost
    ) {
        logReceivedUrl(action: action, payload: payload)

        if !payload.success {
            host.showBridgeMessage("\(actionLabel(action)) failed")
            return
        }

        guard isValidHTTPURL(payload.url) else {
            host.showBridgeMessage("Invalid URL")
            return
        }

        let openInBrowser = payload.openInBrowser || payload.target != "_self"

        DispatchQueue.main.async {
            if openInBrowser {
                openInBrowser(payload.url, host: host)
                if closeAfterBrowser {
                    host.finishWithResult()
                }
            } else {
                host.loadUrlInWebView(payload.url)
            }
        }
    }

    private static func handleSchedule(_ payload: ScheduleBridgeData, host: BridgeCallbackHost) {
        DispatchQueue.main.async {
            if payload.shouldCloseWebView {
                host.finishWithResult()
            }
        }
    }

    private static func logReceivedUrl(action: BridgeAction, payload: UrlBridgeData) {
        let label: String
        switch action {
        case .waitingRoom: label = "WAITING_ROOM callback (type 1)"
        case .openScheduleLink: label = "SCHEDULE_LINK callback (type 3)"
        case .openExternalLink: label = "OPEN_EXTERNAL_LINK callback (type 7)"
        default: label = "\(action) callback"
        }
        print("[WebViewBridge] ========== \(label) ==========")
        print("[WebViewBridge] url=\(payload.url)")
        print("[WebViewBridge] success=\(payload.success) openInBrowser=\(payload.openInBrowser) target=\(payload.target)")
        print("[WebViewBridge] ==========================================")
    }

    private static func parseUrlData(_ data: [String: Any]) -> UrlBridgeData {
        let target = (data["target"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTarget = (target?.isEmpty == false) ? target! : "_blank"
        let openInBrowser: Bool
        if data["openInBrowser"] != nil {
            openInBrowser = parseBool(data["openInBrowser"])
        } else {
            openInBrowser = resolvedTarget != "_self"
        }
        return UrlBridgeData(
            url: data["url"] as? String ?? "",
            success: parseBool(data["success"]),
            openInBrowser: openInBrowser,
            target: resolvedTarget
        )
    }

    private static func parseScheduleData(_ data: [String: Any]) -> ScheduleBridgeData {
        ScheduleBridgeData(
            success: parseBool(data["success"]),
            close: parseBool(data["close"])
        )
    }

    static func parseBool(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String {
            return string == "true" || string == "1"
        }
        return false
    }

    static func parseInt(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func openInBrowser(_ urlString: String, host: BridgeCallbackHost) {
        guard let url = URL(string: urlString) else {
            host.showBridgeMessage("Invalid URL")
            return
        }
        UIApplication.shared.open(url) { success in
            if !success {
                host.showBridgeMessage("Failed to open browser")
            }
        }
    }

    private static func isValidHTTPURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil
        else { return false }
        return true
    }

    private static func actionLabel(_ action: BridgeAction) -> String {
        switch action {
        case .waitingRoom: return "Waiting room"
        case .schedule: return "Schedule"
        case .openScheduleLink: return "Schedule link"
        case .openNativeImagePicker: return "Photo library"
        case .openNativeVideoPicker: return "Video picker"
        case .openNativeFilePicker: return "File picker"
        case .openExternalLink: return "Open link"
        case .getNativeLocation: return "Location"
        }
    }
}
