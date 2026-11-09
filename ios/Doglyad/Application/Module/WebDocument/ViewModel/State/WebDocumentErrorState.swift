import Foundation

@MainActor
final class WebDocumentErrorState: WebDocumentStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: WebDocumentErrorState,
        rhs: WebDocumentErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
