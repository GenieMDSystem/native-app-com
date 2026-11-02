import Foundation
import WebKit

enum NativePickerScript {
    static func evaluate(functionName: String, payload: [String: Any], webView: WKWebView?) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let literal = javaScriptStringLiteral(json)
        else { return }
        let script = "window.\(functionName) && window.\(functionName)(\(literal))"
        DispatchQueue.main.async {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    /// Quotes `value` as a JSON string (`"..."`) so it can be embedded in JavaScript.
    static func javaScriptStringLiteral(_ value: String) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
