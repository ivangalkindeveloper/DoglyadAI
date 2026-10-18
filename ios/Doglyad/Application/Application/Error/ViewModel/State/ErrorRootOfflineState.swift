import Foundation

@MainActor
final class ErrorRootOfflineState: ErrorRootStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ErrorRootOfflineState,
        rhs: ErrorRootOfflineState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
