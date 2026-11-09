import Foundation

@MainActor
final class ReadyMadeTemplateListErrorState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: ReadyMadeTemplateListErrorState,
        rhs: ReadyMadeTemplateListErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
