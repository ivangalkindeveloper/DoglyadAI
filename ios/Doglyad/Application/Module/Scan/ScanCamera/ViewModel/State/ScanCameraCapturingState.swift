import Foundation

@MainActor
final class ScanCameraCapturingState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraCapturingState,
        _: ScanCameraCapturingState,
    ) -> Bool {
        true
    }
}
