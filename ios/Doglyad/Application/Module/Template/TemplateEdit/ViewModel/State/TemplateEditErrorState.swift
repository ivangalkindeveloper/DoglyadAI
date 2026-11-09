import Foundation

@MainActor
final class TemplateEditErrorState: TemplateEditStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: TemplateEditErrorState,
        rhs: TemplateEditErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
