import Foundation

@MainActor
final class ScanCameraReadyState: ScanCameraStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanCameraReadyState,
        _: ScanCameraReadyState,
    ) -> Bool {
        true
    }
}
