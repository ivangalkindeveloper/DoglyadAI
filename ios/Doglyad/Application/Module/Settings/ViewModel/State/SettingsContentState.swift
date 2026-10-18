import Foundation

@MainActor
final class SettingsContentState: SettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: SettingsContentState,
        _: SettingsContentState,
    ) -> Bool {
        true
    }
}
