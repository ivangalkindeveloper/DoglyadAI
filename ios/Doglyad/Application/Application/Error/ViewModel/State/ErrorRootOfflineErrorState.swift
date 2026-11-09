import Foundation

@MainActor
final class ErrorRootOfflineErrorState: ErrorRootStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ErrorRootOfflineErrorState,
        rhs: ErrorRootOfflineErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
