import Foundation

@MainActor
final class ScanInitializationFailedState: ScanStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ScanInitializationFailedState,
        rhs: ScanInitializationFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
