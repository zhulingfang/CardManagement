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

enum PhotoLibraryStoreError: LocalizedError {
    case accessDenied
    case assetNotFound
    case imageDataUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo Library access is required to load or save this photo."
        case .assetNotFound:
            return "The referenced photo is no longer available in your Photo Library. It may have been deleted or may be on another device."
        case .imageDataUnavailable:
            return "The photo exists, but its image data could not be loaded."
        case .saveFailed:
            return "The photo could not be saved to your Photo Library."
        }
    }
}

enum PhotoLibraryStore {
    static func image(for identifier: String) async throws -> UIImage {
        let data = try await imageData(for: identifier)
        guard let image = UIImage(data: data) else {
            throw PhotoLibraryStoreError.imageDataUnavailable
        }
        return image
    }

    static func imageData(for identifier: String) async throws -> Data {
        guard await requestAccessIfNeeded() else {
            throw PhotoLibraryStoreError.accessDenied
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = result.firstObject else {
            throw PhotoLibraryStoreError.assetNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.version = .current

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: PhotoLibraryStoreError.imageDataUnavailable)
                }
            }
        }
    }

    static func saveImageData(_ data: Data) async throws -> String {
        guard await requestAccessIfNeeded() else {
            throw PhotoLibraryStoreError.accessDenied
        }

        var identifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
            identifier = request.placeholderForCreatedAsset?.localIdentifier
        }

        guard let identifier else {
            throw PhotoLibraryStoreError.saveFailed
        }
        return identifier
    }

    private static func requestAccessIfNeeded() async -> Bool {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .authorized || currentStatus == .limited {
            return true
        }
        guard currentStatus == .notDetermined else { return false }

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        return status == .authorized || status == .limited
    }
}
