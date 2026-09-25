import Foundation
import UIKit

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
    func finishWebView()
}

/// Parses `NativeApp.callback` payloads the same way as the Android BrowserBridge.
final class BrowserBridgeHandler {
    private weak var host: BridgeCallbackHost?

    init(host: BridgeCallbackHost) {
        self.host = host
    }

    func handle(json: String) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = root["type"] as? Int else {
            print("[WebViewBridge] invalid callback JSON")
            return
        }

        let payload = root["data"] as? [String: Any] ?? [:]
        guard let action = BridgeAction(rawValue: type) else {
            print("[WebViewBridge] unknown callback type=\(type)")
            return
        }

        switch action {
        case .waitingRoom, .openScheduleLink:
            handleUrlAction(action, payload)
        case .schedule:
            let success = payload["success"] as? Bool ?? false
            let close = payload["close"] as? Bool ?? false
            let parsed = ScheduleBridgeData(success: success, close: close)
            print("[WebViewBridge] SCHEDULE success=\(success) close=\(close)")
            if parsed.shouldCloseWebView {
                DispatchQueue.main.async { self.host?.finishWebView() }
            }
        }
    }

    private func handleUrlAction(_ action: BridgeAction, _ payload: [String: Any]) {
        let url = payload["url"] as? String ?? ""
        let success = payload["success"] as? Bool ?? false
        let openInBrowser = payload["openInBrowser"] as? Bool ?? false
        print("[WebViewBridge] \(action) success=\(success) openInBrowser=\(openInBrowser) url=\(url)")

        guard success else { return }
        guard isValidHttpUrl(url) else {
            print("[WebViewBridge] rejected invalid URL: \(url)")
            return
        }

        DispatchQueue.main.async {
            if openInBrowser {
                if let parsed = URL(string: url) {
                    UIApplication.shared.open(parsed)
                }
                self.host?.finishWebView()
            } else {
                self.host?.loadUrlInWebView(url)
            }
        }
    }

    private func isValidHttpUrl(_ url: String) -> Bool {
        guard let parsed = URL(string: url), let scheme = parsed.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && parsed.host != nil
    }
}
