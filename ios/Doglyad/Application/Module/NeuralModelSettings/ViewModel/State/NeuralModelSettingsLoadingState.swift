import Foundation

@MainActor
final class NeuralModelSettingsLoadingState: NeuralModelSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: NeuralModelSettingsLoadingState,
        _: NeuralModelSettingsLoadingState,
    ) -> Bool {
        true
    }
}
