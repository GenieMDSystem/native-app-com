import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Native replacement for WKWebView's built-in file picker.
/// Uses PHPicker without requesting Photo Library permission, so iOS never
/// shows "Private Access to Photos" / Limited Library — that path freezes the WebView.
final class NativeFilePicker: NSObject, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    struct PickedFile {
        let name: String
        let mime: String
        let base64: String
    }

    private weak var presenter: UIViewController?
    private var completion: (([PickedFile]) -> Void)?

    func present(from presenter: UIViewController, accept: String, multiple: Bool, capture: String, completion: @escaping ([PickedFile]) -> Void) {
        // Always replace the previous completion so a second tap cannot deadlock.
        self.completion = completion
        self.presenter = presenter

        let wantsCamera = !capture.isEmpty || accept.contains("capture")
        if wantsCamera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            presentCamera()
            return
        }

        let sheet = UIAlertController(title: "Upload a photo", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPhotoLibrary(multiple: multiple)
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }
        sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
            self?.presentDocumentPicker(multiple: multiple)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish([])
        })

        if let pop = sheet.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 40, width: 1, height: 1)
        }
        presenter.present(sheet, animated: true)
    }

    func cancelPending() {
        finish([])
    }

    // MARK: - Photo Library (PHPicker, no photo permission)

    private func presentPhotoLibrary(multiple: Bool) {
        guard let presenter else {
            finish([])
            return
        }
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = multiple ? 0 : 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if results.isEmpty {
                self.finish([])
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
                guard let data, let file = NativeFilePicker.makeImageFile(from: data, fallbackName: "photo.jpg") else { return }
                lock.lock()
                files.append(file)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finish(files)
        }
    }

    // MARK: - Camera

    private func presentCamera() {
        guard let presenter, UIImagePickerController.isSourceTypeAvailable(.camera) else {
            finish([])
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
            self?.finish([])
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if let image, let file = NativeFilePicker.makeImageFile(from: image, name: "camera.jpg") {
                self.finish([file])
            } else {
                self.finish([])
            }
        }
    }

    // MARK: - Files

    private func presentDocumentPicker(multiple: Bool) {
        guard let presenter else {
            finish([])
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .jpeg, .png, .heic, .pdf, .data], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = multiple
        presenter.present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish([])
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var files: [PickedFile] = []
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            let name = url.lastPathComponent
            let mime = NativeFilePicker.mimeType(for: url) ?? "application/octet-stream"
            files.append(PickedFile(name: name, mime: mime, base64: data.base64EncodedString()))
        }
        finish(files)
    }

    // MARK: - Helpers

    private func finish(_ files: [PickedFile]) {
        let done = completion
        completion = nil
        DispatchQueue.main.async {
            done?(files)
        }
    }

    static func makeImageFile(from image: UIImage, name: String) -> PickedFile? {
        let scaled = image.resizedToMaxDimension(1600)
        guard let data = scaled.jpegData(compressionQuality: 0.82) else { return nil }
        return PickedFile(name: name, mime: "image/jpeg", base64: data.base64EncodedString())
    }

    static func makeImageFile(from data: Data, fallbackName: String) -> PickedFile? {
        if let image = UIImage(data: data) {
            return makeImageFile(from: image, name: fallbackName)
        }
        return PickedFile(name: fallbackName, mime: "application/octet-stream", base64: data.base64EncodedString())
    }

    static func mimeType(for url: URL) -> String? {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
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
