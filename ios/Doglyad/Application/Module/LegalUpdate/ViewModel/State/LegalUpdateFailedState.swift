import Foundation

@MainActor
final class LegalUpdateFailedState: LegalUpdateStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: LegalUpdateFailedState,
        rhs: LegalUpdateFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
