import Foundation

@MainActor
final class TemplateEditInitializationErrorState: TemplateEditStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateEditInitializationErrorState,
        rhs: TemplateEditInitializationErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
