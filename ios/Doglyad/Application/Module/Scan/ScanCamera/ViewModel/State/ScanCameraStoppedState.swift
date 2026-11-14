import Foundation

@MainActor
final class ScanCameraStoppedState: ScanCameraStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanCameraStoppedState,
        _: ScanCameraStoppedState,
    ) -> Bool {
        true
    }
}
