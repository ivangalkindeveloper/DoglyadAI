import Foundation

@MainActor
final class ScanInitialState: ScanStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanInitialState,
        _: ScanInitialState,
    ) -> Bool {
        true
    }
}
