import Foundation

@MainActor
final class ScanCameraCaptureLoadingState: ScanCameraStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanCameraCaptureLoadingState,
        _: ScanCameraCaptureLoadingState,
    ) -> Bool {
        true
    }
}
