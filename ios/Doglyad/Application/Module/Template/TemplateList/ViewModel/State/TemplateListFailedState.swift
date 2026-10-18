import Foundation

@MainActor
final class TemplateListFailedState: TemplateListStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateListFailedState,
        rhs: TemplateListFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
