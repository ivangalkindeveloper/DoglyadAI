import Foundation

@MainActor
final class ScanCameraPreparationLoadingState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraPreparationLoadingState,
        _: ScanCameraPreparationLoadingState,
    ) -> Bool {
        true
    }
}
