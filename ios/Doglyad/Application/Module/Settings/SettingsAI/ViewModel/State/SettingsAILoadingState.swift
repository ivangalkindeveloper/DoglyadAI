import Foundation

@MainActor
final class SettingsAILoadingState: SettingsAIStateProtocol, @MainActor Equatable {
    static func == (
        _: SettingsAILoadingState,
        _: SettingsAILoadingState,
    ) -> Bool {
        true
    }
}
