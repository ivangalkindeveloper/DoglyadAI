import Foundation

@MainActor
final class SelectTemplateFailedState: SelectTemplateStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: SelectTemplateFailedState,
        rhs: SelectTemplateFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
