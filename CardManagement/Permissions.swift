import AVFoundation
import UIKit
import Photos

class CameraPermissionManager {
    static func checkCameraPermission(
        onAuthorized: @escaping () -> Void,
        onDenied: @escaping () -> Void
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onAuthorized()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        onAuthorized()
                    } else {
                        onDenied()
                    }
                }
            }
        case .denied, .restricted:
            onDenied()
        @unknown default:
            onDenied()
        }
    }
    
    static func checkPhotoLibraryPermission(
        onAuthorized: @escaping () -> Void,
        onDenied: @escaping () -> Void
    ) {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            onAuthorized()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        onAuthorized()
                    } else {
                        onDenied()
                    }
                }
            }
        case .denied, .restricted:
            onDenied()
        @unknown default:
            onDenied()
        }
    }
    
    static func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
