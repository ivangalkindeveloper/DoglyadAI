import Foundation

@MainActor
final class SettingsLoadingState: SettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: SettingsLoadingState,
        _: SettingsLoadingState,
    ) -> Bool {
        true
    }
}
