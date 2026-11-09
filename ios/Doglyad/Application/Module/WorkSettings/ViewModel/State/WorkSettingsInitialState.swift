import Foundation

@MainActor
final class WorkSettingsInitialState: WorkSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: WorkSettingsInitialState,
        _: WorkSettingsInitialState,
    ) -> Bool {
        true
    }
}
