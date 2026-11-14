import Foundation

@MainActor
final class WorkSettingsInitialState: WorkSettingsStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: WorkSettingsInitialState,
        _: WorkSettingsInitialState,
    ) -> Bool {
        true
    }
}
