import Foundation

@MainActor
final class ScanDefaultState: ScanStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanDefaultState,
        _: ScanDefaultState,
    ) -> Bool {
        true
    }
}
