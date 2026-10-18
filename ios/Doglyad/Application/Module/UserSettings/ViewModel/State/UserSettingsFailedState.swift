import Foundation

@MainActor
final class UserSettingsFailedState: UserSettingsStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: UserSettingsFailedState,
        rhs: UserSettingsFailedState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
