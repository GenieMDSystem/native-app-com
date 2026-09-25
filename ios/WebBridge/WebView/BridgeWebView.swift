import SwiftUI
import WebKit

struct BridgeWebView: UIViewRepresentable {
    let url: URL
    var onClose: () -> Void
    var onMessage: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContent = WKUserContentController()
        let script = WKUserScript(
            source: BrowserBridge.injectionSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContent.addUserScript(script)
        userContent.add(context.coordinator, name: BrowserBridge.messageHandlerName)

        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: BrowserBridge.messageHandlerName
        )
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, BridgeCallbackHost {
        var parent: BridgeWebView
        weak var webView: WKWebView?
        var loadURLRequest: String?

        init(parent: BridgeWebView) {
            self.parent = parent
        }

        // MARK: - BridgeCallbackHost

        func loadUrlInWebView(_ url: String) {
            guard let url = URL(string: url) else { return }
            webView?.load(URLRequest(url: url))
        }

        func finishWithResult() {
            parent.onClose()
        }

        func showBridgeMessage(_ message: String) {
            parent.onMessage(message)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == BrowserBridge.messageHandlerName else { return }
            let json: String
            if let string = message.body as? String {
                json = string
            } else if let dict = message.body as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let string = String(data: data, encoding: .utf8) {
                json = string
            } else {
                parent.onMessage("Invalid bridge payload")
                return
            }
            BrowserBridge.handle(json: json, host: self)
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.onMessage("Page failed to load: \(error.localizedDescription)")
        }

        // MARK: - WKUIDelegate (media / permissions)

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        func webView(
            _ webView: WKWebView,
            requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
