import UIKit

/// Shrinks a pinned WebView bottom constraint by the keyboard overlap.
final class KeyboardViewportShrinkper {
    weak var container: UIView?
    var bottomConstraint: NSLayoutConstraint?
    var isEnabled = true {
        didSet {
            if !isEnabled {
                apply(overlap: 0, duration: 0.2, options: .curveEaseInOut)
            }
        }
    }

    private var observers: [NSObjectProtocol] = []

    func start(container: UIView, bottomConstraint: NSLayoutConstraint) {
        stop()
        self.container = container
        self.bottomConstraint = bottomConstraint

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleFrameChange(note)
            }
        )
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.apply(
                    overlap: 0,
                    duration: Self.duration(from: note),
                    options: Self.options(from: note)
                )
            }
        )
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func handleFrameChange(_ note: Notification) {
        guard isEnabled, let container, container.window != nil else {
            apply(overlap: 0, duration: Self.duration(from: note), options: Self.options(from: note))
            return
        }
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardInContainer = container.convert(frame, from: nil)
        let overlap = max(0, container.bounds.maxY - keyboardInContainer.minY)
        apply(overlap: overlap, duration: Self.duration(from: note), options: Self.options(from: note))
    }

    private func apply(overlap: CGFloat, duration: TimeInterval, options: UIView.AnimationOptions) {
        bottomConstraint?.constant = isEnabled ? -overlap : 0
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.container?.layoutIfNeeded()
        }
    }

    private static func duration(from note: Notification) -> TimeInterval {
        (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
    }

    private static func options(from note: Notification) -> UIView.AnimationOptions {
        let curveRaw = (note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue
            ?? UIView.AnimationCurve.easeInOut.rawValue
        return UIView.AnimationOptions(rawValue: UInt(curveRaw << 16))
    }
}
