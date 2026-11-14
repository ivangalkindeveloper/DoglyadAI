import Foundation

@MainActor
final class SettingsAIInitialState: SettingsAIStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SettingsAIInitialState,
        _: SettingsAIInitialState,
    ) -> Bool {
        true
    }
}
