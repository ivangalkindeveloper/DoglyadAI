import Foundation

@MainActor
final class LegalUpdateErrorState: LegalUpdateStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: LegalUpdateErrorState,
        rhs: LegalUpdateErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
