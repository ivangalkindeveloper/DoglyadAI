import Foundation

@MainActor
final class SettingsAIFailedState: SettingsAIStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: SettingsAIFailedState,
        rhs: SettingsAIFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
