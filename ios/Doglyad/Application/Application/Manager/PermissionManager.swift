import AVFoundation
import Photos

enum PermissionType {
    case camera
    case microphone
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

        case .microphone:
            await AVCaptureDevice.requestAccess(for: .audio)

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
