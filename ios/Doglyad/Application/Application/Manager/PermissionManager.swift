import AVFoundation
import Photos
import Speech

enum PermissionType {
    case camera
    case speech
    case photoLibrary
}

protocol PermissionManagerProtocol: AnyObject {
    func isGranted(
        _ type: PermissionType
    ) async -> Bool
}

final class PermissionManager {}

extension PermissionManager: PermissionManagerProtocol {
    func isGranted(
        _ type: PermissionType
    ) async -> Bool {
        switch type {
        case .camera:
            await AVCaptureDevice.requestAccess(for: .video)

        case .speech:
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    switch status {
                    case .authorized:
                        continuation.resume(returning: true)
                    default:
                        continuation.resume(returning: false)
                    }
                }
            }

        case .photoLibrary:
            switch await PHPhotoLibrary.requestAuthorization(for: .readWrite) {
            case .authorized, .limited:
                true
            default:
                false
            }
        }
    }
}
