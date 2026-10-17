import Foundation

@MainActor
final class SettingsFailedState: SettingsStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
