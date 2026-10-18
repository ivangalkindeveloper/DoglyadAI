import Foundation

@MainActor
final class ScanCameraPreparingState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraPreparingState,
        _: ScanCameraPreparingState,
    ) -> Bool {
        true
    }
}
