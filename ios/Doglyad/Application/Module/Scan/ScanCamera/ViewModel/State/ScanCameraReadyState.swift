import Foundation

@MainActor
final class ScanCameraReadyState: ScanCameraStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanCameraReadyState,
        _: ScanCameraReadyState,
    ) -> Bool {
        true
    }
}
