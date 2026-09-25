import SwiftUI
import WebKit

struct WebViewScreen: UIViewControllerRepresentable {
    let url: URL
    var onClose: () -> Void

    func makeUIViewController(context: Context) -> WebViewController {
        let controller = WebViewController(url: url)
        controller.onClose = onClose
        return controller
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, BridgeCallbackHost {
    var onClose: (() -> Void)?

    private let initialURL: URL
    private var webView: WKWebView!
    private let filePicker = NativeFilePicker()
    private lazy var bridge = BrowserBridgeHandler(host: self)
    private var progressView: UIProgressView!
    private var progressObservation: NSKeyValueObservation?

    init(url: URL) {
        self.initialURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureWebView()
        configureProgress()
        webView.load(URLRequest(url: initialURL))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            filePicker.cancelPending()
        }
    }

    deinit {
        progressObservation = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "NativeApp")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "NativeFilePicker")
    }

    private func configureWebView() {
        let contentController = WKUserContentController()
        contentController.addUserScript(WKUserScript(source: WebViewUserScripts.nativeAppBridge, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        contentController.addUserScript(WKUserScript(source: WebViewUserScripts.fileInputIntercept, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let nativeAppHandler = WeakScriptMessageHandler(target: self)
        let filePickerHandler = WeakScriptMessageHandler(target: self)
        contentController.add(nativeAppHandler, name: "NativeApp")
        contentController.add(filePickerHandler, name: "NativeFilePicker")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        let close = UIButton(type: .close)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(close)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    private func configureProgress() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            self.progressView.progress = Float(webView.estimatedProgress)
            self.progressView.isHidden = webView.estimatedProgress >= 1
        }
    }

    // MARK: - BridgeCallbackHost

    func loadUrlInWebView(_ url: String) {
        guard let parsed = URL(string: url) else { return }
        webView.load(URLRequest(url: parsed))
    }

    func finishWebView() {
        onClose?()
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        finishWebView()
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "NativeApp":
            if let json = message.body as? String {
                bridge.handle(json: json)
            } else if let dict = message.body as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let json = String(data: data, encoding: .utf8) {
                bridge.handle(json: json)
            }
        case "NativeFilePicker":
            let body = message.body as? [String: Any] ?? [:]
            let accept = body["accept"] as? String ?? ""
            let multiple = body["multiple"] as? Bool ?? false
            let capture = body["capture"] as? String ?? ""
            filePicker.present(from: self, accept: accept, multiple: multiple, capture: capture) { [weak self] files in
                self?.deliverFilesToPage(files)
            }
        default:
            break
        }
    }

    private func deliverFilesToPage(_ files: [NativeFilePicker.PickedFile]) {
        let payload: [String: Any]
        if files.isEmpty {
            payload = ["cancelled": true]
        } else {
            payload = [
                "cancelled": false,
                "files": files.map { ["name": $0.name, "mime": $0.mime, "base64": $0.base64] }
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.__nativeFilePickerDeliver && window.__nativeFilePickerDeliver(\(json));"
        webView.evaluateJavaScript(js, completionHandler: { _, error in
            if let error {
                print("[WebViewBridge] file deliver JS error: \(error)")
            }
        })
    }

    // MARK: - WKUIDelegate (camera / mic / geolocation)

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[WebViewBridge] navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[WebViewBridge] provisional failed: \(error.localizedDescription)")
    }
}

/// Breaks the WKUserContentController ↔ controller retain cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
