import Foundation

@MainActor
final class ScanInitializationErrorState: ScanStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ScanInitializationErrorState,
        rhs: ScanInitializationErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
