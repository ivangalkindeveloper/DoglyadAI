import Foundation

@MainActor
final class ScanCameraStoppedState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraStoppedState,
        _: ScanCameraStoppedState,
    ) -> Bool {
        true
    }
}
