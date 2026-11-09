import Foundation

@MainActor
final class UserSettingsErrorState: UserSettingsStateProtocol, @MainActor Equatable {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    static func == (
        lhs: UserSettingsErrorState,
        rhs: UserSettingsErrorState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
