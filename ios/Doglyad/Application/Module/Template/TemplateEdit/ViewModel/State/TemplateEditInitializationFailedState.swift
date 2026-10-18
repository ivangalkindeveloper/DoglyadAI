import Foundation

@MainActor
final class TemplateEditInitializationFailedState: TemplateEditStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateEditInitializationFailedState,
        rhs: TemplateEditInitializationFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
