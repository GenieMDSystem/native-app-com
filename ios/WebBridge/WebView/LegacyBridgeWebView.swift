import SwiftUI
import UIKit
import WebKit

/// Legacy hybrid WebView path used by many older client apps:
/// - Intercepts `<input type="file">`
/// - Presents `UIImagePickerController` (old Photo Library API)
/// - On dismiss, encodes the image to JPEG/base64 and injects it via `evaluateJavaScript` **on the main thread**
///
/// That post-dismiss main-thread work is a common way apps freeze after Photo Library dismissal.
/// (`UIWebView` itself is removed from modern iOS SDKs, so this is the realistic "old WebView" stack.)
struct LegacyBridgeWebView: UIViewControllerRepresentable {
    let url: URL
    var onClose: () -> Void
    var onMessage: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> LegacyWebViewController {
        let controller = LegacyWebViewController()
        controller.coordinator = context.coordinator
        context.coordinator.controller = controller
        controller.load(url: url)
        return controller
    }

    func updateUIViewController(_ uiViewController: LegacyWebViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.controller = uiViewController
    }

    static func dismantleUIViewController(_ uiViewController: LegacyWebViewController, coordinator: Coordinator) {
        uiViewController.teardown()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate, BridgeCallbackHost {
        var parent: LegacyBridgeWebView
        weak var controller: LegacyWebViewController?

        init(parent: LegacyBridgeWebView) {
            self.parent = parent
        }

        // MARK: - BridgeCallbackHost

        func loadUrlInWebView(_ url: String) {
            guard let url = URL(string: url) else { return }
            controller?.webView.load(URLRequest(url: url))
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
            switch message.name {
            case BrowserBridge.messageHandlerName:
                handleNativeAppMessage(message.body)
            case "LegacyPickPhoto":
                presentLegacyPhotoPicker()
            default:
                break
            }
        }

        private func handleNativeAppMessage(_ body: Any) {
            let json: String
            if let string = body as? String {
                json = string
            } else if let dict = body as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let string = String(data: data, encoding: .utf8) {
                json = string
            } else {
                parent.onMessage("Invalid bridge payload")
                return
            }
            BrowserBridge.handle(json: json, host: self)
        }

        // MARK: - Legacy photo picker

        func presentLegacyPhotoPicker() {
            guard let presenter = controller else { return }

            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.allowsEditing = false
            picker.modalPresentationStyle = .fullScreen

            parent.onMessage("Legacy Photo Library opened")
            presenter.present(picker, animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { [weak self] in
                self?.parent.onMessage("Photo Library cancelled")
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Intentionally keep heavy work on the main thread after dismiss —
            // this matches older client hybrid patterns and is what freezes the UI.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)

            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                guard let image else {
                    self.parent.onMessage("No image selected")
                    return
                }

                self.parent.onMessage("Encoding photo on main thread…")
                self.injectImageOnMainThread(image)
            }
        }

        /// Classic freeze recipe: full-resolution JPEG + base64 + huge evaluateJavaScript on main.
        private func injectImageOnMainThread(_ image: UIImage) {
            assert(Thread.isMainThread)

            // No downscaling — same as many older apps feeding camera-roll originals into JS.
            guard let jpeg = image.jpegData(compressionQuality: 0.92) else {
                parent.onMessage("Failed to encode JPEG")
                return
            }

            let base64 = jpeg.base64EncodedString()
            let fileName = "legacy_upload_\(Int(Date().timeIntervalSince1970)).jpg"
            let script = LegacyPhotoScripts.assignFileScript(
                base64: base64,
                fileName: fileName,
                mimeType: "image/jpeg"
            )

            controller?.webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error {
                    self?.parent.onMessage("Inject failed: \(error.localizedDescription)")
                } else {
                    self?.parent.onMessage("Legacy photo injected (\(jpeg.count / 1024) KB)")
                }
            }
        }

        // MARK: - WKNavigationDelegate / WKUIDelegate

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

// MARK: - UIKit host (older-style full-screen WebView controller)

final class LegacyWebViewController: UIViewController {
    private(set) lazy var webView: WKWebView = makeWebView()
    weak var coordinator: LegacyBridgeWebView.Coordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func load(url: URL) {
        _ = webView
        webView.load(URLRequest(url: url))
    }

    func teardown() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: BrowserBridge.messageHandlerName)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "LegacyPickPhoto")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    private func makeWebView() -> WKWebView {
        let userContent = WKUserContentController()
        userContent.addUserScript(
            WKUserScript(
                source: BrowserBridge.injectionSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        userContent.addUserScript(
            WKUserScript(
                source: LegacyPhotoScripts.fileInputInterceptSource,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        if let coordinator {
            userContent.add(coordinator, name: BrowserBridge.messageHandlerName)
            userContent.add(coordinator, name: "LegacyPickPhoto")
        }

        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // Older-style: dedicated process pool (no sharing)
        config.processPool = WKProcessPool()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
}

// MARK: - Injected scripts

enum LegacyPhotoScripts {
    /// Intercept file inputs and route them through the legacy native Photo Library picker.
    static let fileInputInterceptSource = """
    (function() {
      if (window.__legacyPhotoInterceptInstalled) { return; }
      window.__legacyPhotoInterceptInstalled = true;

      function isFileInput(el) {
        return el && el.tagName === 'INPUT' && (el.type || '').toLowerCase() === 'file';
      }

      function openLegacyPicker(el) {
        try {
          window.__legacyActiveFileInput = el;
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.LegacyPickPhoto) {
            window.webkit.messageHandlers.LegacyPickPhoto.postMessage('pick');
          }
        } catch (e) {
          console.warn('LegacyPickPhoto failed', e);
        }
      }

      document.addEventListener('click', function(e) {
        var t = e.target;
        if (!t) { return; }
        if (isFileInput(t) || (t.closest && isFileInput(t.closest('input[type=file]')))) {
          e.preventDefault();
          e.stopPropagation();
          openLegacyPicker(isFileInput(t) ? t : t.closest('input[type=file]'));
        }
      }, true);

      document.addEventListener('change', function() {}, true);
    })();
    """

    static func assignFileScript(base64: String, fileName: String, mimeType: String) -> String {
        // Escape for JS string literal
        let safeBase64 = base64
        let safeName = fileName.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let safeMime = mimeType.replacingOccurrences(of: "'", with: "\\'")

        return """
        (function() {
          var base64 = '\(safeBase64)';
          var fileName = '\(safeName)';
          var mimeType = '\(safeMime)';
          function b64ToUint8(b64) {
            var bin = atob(b64);
            var len = bin.length;
            var bytes = new Uint8Array(len);
            for (var i = 0; i < len; i++) { bytes[i] = bin.charCodeAt(i); }
            return bytes;
          }
          try {
            var bytes = b64ToUint8(base64);
            var blob = new Blob([bytes], { type: mimeType });
            var file = new File([blob], fileName, { type: mimeType });
            var input = window.__legacyActiveFileInput;
            if (!input) {
              input = document.querySelector('input[type=file]');
            }
            if (!input) {
              console.warn('No file input found for legacy photo inject');
              return false;
            }
            var dt = new DataTransfer();
            dt.items.add(file);
            input.files = dt.files;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          } catch (e) {
            console.error('legacy assign failed', e);
            throw e;
          }
        })();
        """
    }
}
