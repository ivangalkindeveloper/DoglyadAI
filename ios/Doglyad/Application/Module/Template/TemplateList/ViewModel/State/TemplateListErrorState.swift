import Foundation

@MainActor
final class TemplateListErrorState: TemplateListStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateListErrorState,
        rhs: TemplateListErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
