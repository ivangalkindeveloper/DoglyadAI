import Foundation

@MainActor
final class UserSettingsLoadingState: UserSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: UserSettingsLoadingState,
        _: UserSettingsLoadingState,
    ) -> Bool {
        true
    }
}
