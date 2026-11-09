import Foundation

@MainActor
final class ScanErrorState: ScanStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ScanErrorState,
        rhs: ScanErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
