import Foundation

@MainActor
final class ScanCameraCaptureLoadingState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraCaptureLoadingState,
        _: ScanCameraCaptureLoadingState,
    ) -> Bool {
        true
    }
}
