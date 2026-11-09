import Foundation

@MainActor
final class SettingsAIInitialState: SettingsAIStateProtocol, @MainActor Equatable {
    static func == (
        _: SettingsAIInitialState,
        _: SettingsAIInitialState,
    ) -> Bool {
        true
    }
}
