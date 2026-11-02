import CoreLocation
import Foundation
import WebKit

/// Type 8 location. Answers the page with `window.onNativeLocation(jsonString)`.
final class NativeLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private weak var webView: WKWebView?
    private var timeoutWork: DispatchWorkItem?
    private var didDeliver = false
    private var pendingHighAccuracy = false
    private var pendingTimeoutMs = 30_000
    private var waitingForAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func request(from webView: WKWebView, enableHighAccuracy: Bool, timeoutMs: Int) {
        cancel()
        self.webView = webView
        didDeliver = false
        pendingHighAccuracy = enableHighAccuracy
        pendingTimeoutMs = max(timeoutMs, 1000)
        manager.desiredAccuracy = enableHighAccuracy
            ? kCLLocationAccuracyBest
            : kCLLocationAccuracyHundredMeters

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdates()
        case .notDetermined:
            waitingForAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            deliver(success: false, code: 1, permissionDenied: true, message: "Location permission denied")
        @unknown default:
            deliver(success: false, code: 2, message: "Location provider unavailable")
        }
    }

    func cancel() {
        timeoutWork?.cancel()
        timeoutWork = nil
        manager.stopUpdatingLocation()
        waitingForAuthorization = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            waitingForAuthorization = false
            startUpdates()
        case .denied, .restricted:
            waitingForAuthorization = false
            deliver(success: false, code: 1, permissionDenied: true, message: "Location permission denied")
        case .notDetermined:
            break
        @unknown default:
            waitingForAuthorization = false
            deliver(success: false, code: 2, message: "Location provider unavailable")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        deliver(
            success: true,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .denied {
            deliver(success: false, code: 1, permissionDenied: true, message: "Location permission denied")
            return
        }
        deliver(success: false, code: 2, message: error.localizedDescription)
    }

    private func startUpdates() {
        if let last = manager.location,
           Date().timeIntervalSince(last.timestamp) <= 60 {
            deliver(
                success: true,
                latitude: last.coordinate.latitude,
                longitude: last.coordinate.longitude
            )
            return
        }

        manager.startUpdatingLocation()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let last = self.manager.location {
                self.deliver(
                    success: true,
                    latitude: last.coordinate.latitude,
                    longitude: last.coordinate.longitude
                )
            } else {
                self.deliver(success: false, code: 3, message: "Location request timed out")
            }
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(pendingTimeoutMs), execute: work)
    }

    private func deliver(
        success: Bool,
        code: Int? = nil,
        permissionDenied: Bool? = nil,
        message: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        if didDeliver { return }
        didDeliver = true
        cancel()

        var payload: [String: Any] = ["success": success]
        if let code { payload["code"] = code }
        if let permissionDenied { payload["permissionDenied"] = permissionDenied }
        if let message { payload["message"] = message }
        if let latitude { payload["latitude"] = latitude }
        if let longitude { payload["longitude"] = longitude }

        print("[WebViewBridge] onNativeLocation success=\(success) code=\(code ?? -1)")
        NativePickerScript.evaluate(functionName: "onNativeLocation", payload: payload, webView: webView)
    }
}
