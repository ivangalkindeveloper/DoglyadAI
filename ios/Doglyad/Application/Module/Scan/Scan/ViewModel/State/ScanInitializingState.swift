import Foundation

@MainActor
final class ScanInitializingState: ScanStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanInitializingState,
        _: ScanInitializingState,
    ) -> Bool {
        true
    }
}
