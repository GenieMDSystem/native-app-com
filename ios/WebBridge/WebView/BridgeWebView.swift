import SwiftUI
import UIKit
import WebKit

struct BridgeWebView: UIViewRepresentable {
    let url: URL
    var shrinkViewportOnKeyboard: Bool = false
    var onClose: () -> Void
    var onMessage: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
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

        let container = UIView()
        container.backgroundColor = .white

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)

        let bottom = webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottom,
        ])

        context.coordinator.webView = webView
        context.coordinator.keyboardShrinkper.isEnabled = shrinkViewportOnKeyboard
        context.coordinator.keyboardShrinkper.start(container: container, bottomConstraint: bottom)
        webView.load(URLRequest(url: url))
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.keyboardShrinkper.isEnabled = shrinkViewportOnKeyboard
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.keyboardShrinkper.stop()
        coordinator.webView?.stopLoading()
        coordinator.webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: BrowserBridge.messageHandlerName
        )
        coordinator.webView?.navigationDelegate = nil
        coordinator.webView?.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, BridgeCallbackHost {
        var parent: BridgeWebView
        weak var webView: WKWebView?
        var loadURLRequest: String?
        let keyboardShrinkper = KeyboardViewportShrinkper()
        private let imagePicker = NativeImagePicker()
        private let location = NativeLocation()

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

        func openNativeImagePicker(multiple: Bool) {
            guard let webView else {
                parent.onMessage("Photo picker unavailable")
                return
            }
            imagePicker.present(from: webView, multiple: multiple)
        }

        func openNativeVideoPicker() {
            guard let webView else {
                parent.onMessage("Video picker unavailable")
                return
            }
            imagePicker.presentVideo(from: webView)
        }

        func openNativeFilePicker() {
            guard let webView else {
                parent.onMessage("File picker unavailable")
                return
            }
            imagePicker.presentFile(from: webView)
        }

        func getNativeLocation(enableHighAccuracy: Bool, timeoutMs: Int) {
            guard let webView else {
                parent.onMessage("Location unavailable")
                return
            }
            location.request(from: webView, enableHighAccuracy: enableHighAccuracy, timeoutMs: timeoutMs)
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
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "tel" || scheme == "mailto" || scheme == "sms" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
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
