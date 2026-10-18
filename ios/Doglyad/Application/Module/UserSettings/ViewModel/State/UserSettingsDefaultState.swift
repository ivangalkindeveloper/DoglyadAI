import Foundation

@MainActor
final class UserSettingsDefaultState: UserSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: UserSettingsDefaultState,
        _: UserSettingsDefaultState,
    ) -> Bool {
        true
    }
}
