import Foundation

@MainActor
final class UserSettingsFailedState: UserSettingsStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
