import Foundation

@MainActor
final class UserSettingsInitialState: UserSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: UserSettingsInitialState,
        _: UserSettingsInitialState,
    ) -> Bool {
        true
    }
}
