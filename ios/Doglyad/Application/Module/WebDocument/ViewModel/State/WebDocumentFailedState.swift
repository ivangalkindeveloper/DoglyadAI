import Foundation

@MainActor
final class WebDocumentFailedState: WebDocumentStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: WebDocumentFailedState,
        rhs: WebDocumentFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
