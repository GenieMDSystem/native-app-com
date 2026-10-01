import AVFoundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import WebKit
 
/// Native Take Photo / Photo Library chooser for type 4.
/// Answers the page with `window.onNativeImagePicked(jsonString)` like Android.
final class NativeImagePicker: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    struct PickedFile {
        let mimeType: String
        let dataUrl: String
        let fileName: String
    }
 
    private static let maxPassThroughBytes = 1_500_000
    private static let passThroughMimes: Set<String> = [
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/gif"
    ]
 
    private weak var webView: WKWebView?
    private var allowsMultiple = false
    private var didDeliver = false
 
    func present(from webView: WKWebView, multiple: Bool) {
        self.webView = webView
        self.allowsMultiple = multiple
        self.didDeliver = false
 
        guard let presenter = Self.topPresenter(from: webView) else {
            deliver(cancelled: true, files: [])
            return
        }
 
        let sheet = UIAlertController(title: "Upload a photo", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.requestCameraThenCapture(from: presenter)
            })
        }
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary(from: presenter)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.deliver(cancelled: true, files: [])
        })
 
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 40,
                width: 1,
                height: 1
            )
        }
        presenter.present(sheet, animated: true)
    }
 
    // MARK: - Photo Library (PHPicker, no photo permission)
 
    private func presentPhotoLibrary(from presenter: UIViewController) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = allowsMultiple ? 0 : 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }
 
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if results.isEmpty {
                self.deliver(cancelled: true, files: [])
                return
            }
            self.loadPickerResults(results)
        }
    }
 
    private func loadPickerResults(_ results: [PHPickerResult]) {
        let group = DispatchGroup()
        var files: [PickedFile] = []
        let lock = NSLock()
 
        for result in results {
            group.enter()
            let suggestedName = result.itemProvider.suggestedName
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let file = NativeImagePicker.encodeImage(data, suggestedName: suggestedName) else { return }
                lock.lock()
                files.append(file)
                lock.unlock()
            }
        }
 
        group.notify(queue: .main) { [weak self] in
            if files.isEmpty {
                self?.deliver(cancelled: true, files: [])
            } else {
                self?.deliver(cancelled: false, files: files)
            }
        }
    }
 
    // MARK: - Camera
 
    private func requestCameraThenCapture(from presenter: UIViewController) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera(from: presenter)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCamera(from: presenter)
                    } else {
                        self?.deliver(cancelled: true, files: [])
                    }
                }
            }
        default:
            deliver(cancelled: true, files: [])
        }
    }
 
    private func presentCamera(from presenter: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            deliver(cancelled: true, files: [])
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        presenter.present(picker, animated: true)
    }
 
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.deliver(cancelled: true, files: [])
        }
    }
 
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            if let image, let file = NativeImagePicker.encodeJPEG(image, fileName: "native-photo.jpg") {
                self?.deliver(cancelled: false, files: [file])
            } else {
                self?.deliver(cancelled: true, files: [])
            }
        }
    }
 
    // MARK: - Deliver to page
 
    private func deliver(cancelled: Bool, files: [PickedFile]) {
        if cancelled && didDeliver { return }
        if cancelled { didDeliver = true }
 
        let fileMaps: [[String: String]] = files.map {
            [
                "mimeType": $0.mimeType,
                "fileName": $0.fileName,
                "dataUrl": $0.dataUrl
            ]
        }
        let payload: [String: Any] = [
            "cancelled": cancelled,
            "success": !cancelled && !files.isEmpty,
            "files": fileMaps
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let literal = Self.javaScriptStringLiteral(json)
        else { return }
 
        print("[WebViewBridge] onNativeImagePicked cancelled=\(cancelled) count=\(files.count)")
        let script = "window.onNativeImagePicked && window.onNativeImagePicked(\(literal))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }
 
    /// Quotes `value` as a JSON string (`"..."`) so it can be embedded in JavaScript.
    /// `JSONSerialization` only accepts an array or dictionary at the top level; a bare
    /// string raises `NSInvalidArgumentException`, which `try?` does not catch.
    private static func javaScriptStringLiteral(_ value: String) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
 
    static func encodeImage(_ data: Data, suggestedName: String?) -> PickedFile? {
        guard !data.isEmpty else { return nil }
        let sourceMime = imageMime(data)
        let passThrough = Self.passThroughMimes.contains(sourceMime) && data.count <= Self.maxPassThroughBytes
        if passThrough {
            let mimeType = sourceMime
            let fileName = fileName(suggestedName: suggestedName, mimeType: mimeType)
            return PickedFile(
                mimeType: mimeType,
                dataUrl: "data:\(mimeType);base64,\(data.base64EncodedString())",
                fileName: fileName
            )
        }
        guard let image = UIImage(data: data) else { return nil }
        return encodeJPEG(image, fileName: fileName(suggestedName: suggestedName, mimeType: "image/jpeg"))
    }
 
    static func encodeJPEG(_ image: UIImage, fileName: String) -> PickedFile? {
        let scaled = image.resizedToMaxDimension(1600)
        guard let data = scaled.jpegData(compressionQuality: 0.90) else { return nil }
        return PickedFile(
            mimeType: "image/jpeg",
            dataUrl: "data:image/jpeg;base64,\(data.base64EncodedString())",
            fileName: fileName
        )
    }
 
    private static func fileName(suggestedName: String?, mimeType: String) -> String {
        let ext = extensionFor(mimeType)
        let raw = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return "native-photo.\(ext)"
        }
        if raw.contains(".") {
            return raw
        }
        return "\(raw).\(ext)"
    }
 
    private static func imageMime(_ data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "image/jpeg"
        }
        if bytes.count >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        if bytes.count >= 12 {
            let riff = String(bytes: bytes[0..<4], encoding: .ascii)
            let webp = String(bytes: bytes[8..<12], encoding: .ascii)
            if riff == "RIFF" && webp == "WEBP" {
                return "image/webp"
            }
        }
        if bytes.count >= 6, let header = String(bytes: bytes[0..<6], encoding: .ascii),
           header == "GIF87a" || header == "GIF89a" {
            return "image/gif"
        }
        return "image/jpeg"
    }
 
    private static func extensionFor(_ mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        default: return "jpg"
        }
    }
 
    static func topPresenter(from view: UIView) -> UIViewController? {
        var controller = view.window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
 
private extension UIImage {
    func resizedToMaxDimension(_ maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
 