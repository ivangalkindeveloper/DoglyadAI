import Foundation

@MainActor
final class SettingsAIDefaultState: SettingsAIStateProtocol, @MainActor Equatable {
    static func == (
        _: SettingsAIDefaultState,
        _: SettingsAIDefaultState,
    ) -> Bool {
        true
    }
}
