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
    }

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
                self?.presentCamera(from: presenter)
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
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let file = NativeImagePicker.encodeJPEG(data) else { return }
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
            if let image, let file = NativeImagePicker.encodeJPEG(image) {
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
            ["mimeType": $0.mimeType, "dataUrl": $0.dataUrl]
        }
        let payload: [String: Any] = [
            "cancelled": cancelled,
            "success": !cancelled && !files.isEmpty,
            "files": fileMaps
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let quoted = try? JSONSerialization.data(withJSONObject: json),
              let literal = String(data: quoted, encoding: .utf8)
        else { return }

        print("[WebViewBridge] onNativeImagePicked cancelled=\(cancelled) count=\(files.count)")
        let script = "window.onNativeImagePicked && window.onNativeImagePicked(\(literal))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    static func encodeJPEG(_ image: UIImage) -> PickedFile? {
        let scaled = image.resizedToMaxDimension(1600)
        guard let data = scaled.jpegData(compressionQuality: 0.80) else { return nil }
        return PickedFile(
            mimeType: "image/jpeg",
            dataUrl: "data:image/jpeg;base64,\(data.base64EncodedString())"
        )
    }

    static func encodeJPEG(_ data: Data) -> PickedFile? {
        guard let image = UIImage(data: data) else { return nil }
        return encodeJPEG(image)
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
