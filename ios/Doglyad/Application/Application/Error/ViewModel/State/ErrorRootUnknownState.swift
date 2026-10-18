import Foundation

@MainActor
final class ErrorRootUnknownState: ErrorRootStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ErrorRootUnknownState,
        rhs: ErrorRootUnknownState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
