import AVFoundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import WebKit
 
/// Native pickers for types 4 (photo), 5 (video), and 6 (document).
/// Answers the matching `window.onNative*Picked(jsonString)` callback.
final class NativeImagePicker: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    enum Kind {
        case image
        case video
        case file

        var jsCallback: String {
            switch self {
            case .image: return "onNativeImagePicked"
            case .video: return "onNativeVideoPicked"
            case .file: return "onNativeFilePicked"
            }
        }
    }

    struct PickedFile {
        let mimeType: String
        let dataUrl: String
        let fileName: String
    }

    private static let maxPassThroughBytes = 1_500_000
    private static let maxBridgeFileBytes = 20_000_000
    private static let passThroughMimes: Set<String> = [
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/gif"
    ]

    private weak var webView: WKWebView?
    private var allowsMultiple = false
    private var didDeliver = false
    private var kind: Kind = .image
 
    func present(from webView: WKWebView, multiple: Bool) {
        self.webView = webView
        self.allowsMultiple = multiple
        self.didDeliver = false
        self.kind = .image
 
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

    func presentVideo(from webView: WKWebView) {
        begin(from: webView, kind: .video, multiple: false)
        guard let presenter = Self.topPresenter(from: webView) else {
            deliver(cancelled: true, files: [])
            return
        }

        let sheet = UIAlertController(title: "Upload a video", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Record Video", style: .default) { [weak self] _ in
                self?.requestCameraThenRecord(from: presenter)
            })
        }
        sheet.addAction(UIAlertAction(title: "Video Library", style: .default) { [weak self] _ in
            self?.presentVideoLibrary(from: presenter)
        })
        sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
            self?.presentVideoFile(from: presenter)
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

    func presentFile(from webView: WKWebView) {
        begin(from: webView, kind: .file, multiple: false)
        guard let presenter = Self.topPresenter(from: webView) else {
            deliver(cancelled: true, files: [])
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presenter.present(picker, animated: true)
    }

    private func begin(from webView: WKWebView, kind: Kind, multiple: Bool) {
        self.webView = webView
        self.kind = kind
        self.allowsMultiple = multiple
        self.didDeliver = false
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

    private func presentVideoLibrary(from presenter: UIViewController) {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    private func presentVideoFile(from presenter: UIViewController) {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.movie],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
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

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        deliver(cancelled: true, files: [])
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            deliver(cancelled: true, files: [])
            return
        }
        let fallbackName = kind == .video ? "native-video" : "native-file"
        let defaultMime = kind == .video ? "video/mp4" : "application/octet-stream"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let file = NativeImagePicker.encodeRawFile(
                url: url,
                fallbackName: fallbackName,
                defaultMime: defaultMime
            )
            DispatchQueue.main.async {
                if let file {
                    self?.deliver(cancelled: false, files: [file])
                } else {
                    self?.deliver(cancelled: true, files: [])
                }
            }
        }
    }

    private func loadPickerResults(_ results: [PHPickerResult]) {
        let group = DispatchGroup()
        var files: [PickedFile] = []
        let lock = NSLock()
        let kind = self.kind

        for result in results {
            group.enter()
            if kind == .video {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    defer { group.leave() }
                    guard let url,
                          let file = NativeImagePicker.encodeRawFile(
                            url: url,
                            fallbackName: "native-video",
                            defaultMime: "video/mp4"
                          )
                    else { return }
                    lock.lock()
                    files.append(file)
                    lock.unlock()
                }
            } else {
                let suggestedName = result.itemProvider.suggestedName
                result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    defer { group.leave() }
                    guard let data, let file = NativeImagePicker.encodeImage(data, suggestedName: suggestedName) else { return }
                    lock.lock()
                    files.append(file)
                    lock.unlock()
                }
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

    private func requestCameraThenRecord(from presenter: UIViewController) {
        requestMediaAccess(.video) { [weak self] cameraGranted in
            guard let self else { return }
            guard cameraGranted else {
                self.deliver(cancelled: true, files: [])
                return
            }
            self.requestMediaAccess(.audio) { [weak self] _ in
                self?.presentVideoCamera(from: presenter)
            }
        }
    }

    private func requestMediaAccess(_ media: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: media) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func presentVideoCamera(from presenter: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            deliver(cancelled: true, files: [])
            return
        }
        let movieType = UTType.movie.identifier
        let available = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        guard available.contains(movieType) else {
            deliver(cancelled: true, files: [])
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [movieType]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeMedium
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
        let mediaURL = info[.mediaURL] as? URL
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if self.kind == .video {
                guard let mediaURL else {
                    self.deliver(cancelled: true, files: [])
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let file = NativeImagePicker.encodeRawFile(
                        url: mediaURL,
                        fallbackName: "native-video",
                        defaultMime: "video/mp4"
                    )
                    DispatchQueue.main.async {
                        if let file {
                            self.deliver(cancelled: false, files: [file])
                        } else {
                            self.deliver(cancelled: true, files: [])
                        }
                    }
                }
                return
            }
            if let image, let file = NativeImagePicker.encodeJPEG(image, fileName: "native-photo.jpg") {
                self.deliver(cancelled: false, files: [file])
            } else {
                self.deliver(cancelled: true, files: [])
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
        print("[WebViewBridge] \(kind.jsCallback) cancelled=\(cancelled) count=\(files.count)")
        NativePickerScript.evaluate(functionName: kind.jsCallback, payload: payload, webView: webView)
    }
 
    static func encodeImage(_ data: Data, suggestedName: String?) -> PickedFile? {
        guard !data.isEmpty else { return nil }
        let sourceMime = imageMime(data)
        let passThrough = Self.passThroughMimes.contains(sourceMime) && data.count <= Self.maxPassThroughBytes
        if passThrough {
            let mimeType = sourceMime
            let fileName = fileName(suggestedName: suggestedName, mimeType: mimeType, fallbackName: "native-photo")
            return PickedFile(
                mimeType: mimeType,
                dataUrl: "data:\(mimeType);base64,\(data.base64EncodedString())",
                fileName: fileName
            )
        }
        guard let image = UIImage(data: data) else { return nil }
        return encodeJPEG(image, fileName: fileName(suggestedName: suggestedName, mimeType: "image/jpeg", fallbackName: "native-photo"))
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
 
    static func encodeRawFile(url: URL, fallbackName: String, defaultMime: String) -> PickedFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return encodeRawBytes(
            data,
            suggestedName: url.lastPathComponent,
            fallbackName: fallbackName,
            defaultMime: mimeFromPath(url.lastPathComponent) ?? defaultMime
        )
    }

    static func encodeRawBytes(
        _ data: Data?,
        suggestedName: String?,
        fallbackName: String,
        defaultMime: String
    ) -> PickedFile? {
        guard let data, !data.isEmpty, data.count <= maxBridgeFileBytes else { return nil }
        let mimeType = defaultMime
        let name = fileName(suggestedName: suggestedName, mimeType: mimeType, fallbackName: fallbackName)
        return PickedFile(
            mimeType: mimeType,
            dataUrl: "data:\(mimeType);base64,\(data.base64EncodedString())",
            fileName: name
        )
    }

    private static func mimeFromPath(_ name: String) -> String? {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "csv": return "text/csv"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return nil
        }
    }

    private static func fileName(suggestedName: String?, mimeType: String, fallbackName: String = "native-photo") -> String {
        let ext = extensionFor(mimeType)
        let raw = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return "\(fallbackName).\(ext)"
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
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "application/pdf": return "pdf"
        case "application/octet-stream": return "bin"
        default: return mimeType.split(separator: "/").last.map(String.init)?.split(separator: "+").first.map(String.init) ?? "bin"
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
 