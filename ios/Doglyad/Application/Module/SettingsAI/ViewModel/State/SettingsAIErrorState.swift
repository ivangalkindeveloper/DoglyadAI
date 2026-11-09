import Foundation

@MainActor
final class SettingsAIErrorState: SettingsAIStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: SettingsAIErrorState,
        rhs: SettingsAIErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
