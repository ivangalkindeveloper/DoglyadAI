import Foundation

@MainActor
final class ReadyMadeTemplateListFailedState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ReadyMadeTemplateListFailedState,
        rhs: ReadyMadeTemplateListFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
