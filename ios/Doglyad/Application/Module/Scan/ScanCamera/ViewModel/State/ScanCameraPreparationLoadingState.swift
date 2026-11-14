import Foundation

@MainActor
final class ScanCameraPreparationLoadingState: ScanCameraStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanCameraPreparationLoadingState,
        _: ScanCameraPreparationLoadingState,
    ) -> Bool {
        true
    }
}
