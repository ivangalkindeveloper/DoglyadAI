import Foundation

@MainActor
final class TemplateAddErrorState: TemplateAddStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateAddErrorState,
        rhs: TemplateAddErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
