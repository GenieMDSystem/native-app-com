import Foundation
import UIKit

/// Callback types from JavaScript → native.
///
/// type 1 WAITING_ROOM: { type: 1, data: { url, success, openInBrowser } }
/// type 2 SCHEDULE / CLOSE: { type: 2, data: { success / close } }
/// type 3 OPEN_SCHEDULE_LINK: { type: 3, data: { url, success, openInBrowser } }
enum BridgeAction: Int {
    case waitingRoom = 1
    case schedule = 2
    case openScheduleLink = 3
}

struct UrlBridgeData {
    let url: String
    let success: Bool
    let openInBrowser: Bool
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
}

/// Parses `NativeApp.callback(json)` payloads from the WebView.
enum BrowserBridge {
    static let interfaceName = "NativeApp"
    static let messageHandlerName = "NativeApp"

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
    })();
    """

    static func handle(json: String, host: BridgeCallbackHost) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = root["type"] as? Int
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
            handleUrlAction(action: action, payload: parseUrlData(dataObj), host: host)
        case .schedule:
            handleSchedule(parseScheduleData(dataObj), host: host)
        }
    }

    private static func handleUrlAction(action: BridgeAction, payload: UrlBridgeData, host: BridgeCallbackHost) {
        if !payload.success {
            host.showBridgeMessage("\(actionLabel(action)) failed")
            return
        }

        guard isValidHTTPURL(payload.url) else {
            host.showBridgeMessage("Invalid URL")
            return
        }

        DispatchQueue.main.async {
            if payload.openInBrowser {
                openInBrowser(payload.url, host: host)
                host.finishWithResult()
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

    private static func parseUrlData(_ data: [String: Any]) -> UrlBridgeData {
        UrlBridgeData(
            url: data["url"] as? String ?? "",
            success: data["success"] as? Bool ?? false,
            openInBrowser: data["openInBrowser"] as? Bool ?? false
        )
    }

    private static func parseScheduleData(_ data: [String: Any]) -> ScheduleBridgeData {
        ScheduleBridgeData(
            success: data["success"] as? Bool ?? false,
            close: data["close"] as? Bool ?? false
        )
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
        }
    }
}
