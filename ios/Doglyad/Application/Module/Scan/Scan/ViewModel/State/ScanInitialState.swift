import Foundation

@MainActor
final class ScanInitialState: ScanStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanInitialState,
        _: ScanInitialState,
    ) -> Bool {
        true
    }
}
