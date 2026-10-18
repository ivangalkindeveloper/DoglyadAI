import Foundation

@MainActor
final class NeuralModelSettingsDefaultState: NeuralModelSettingsStateProtocol, @MainActor Equatable {
    static func == (
        _: NeuralModelSettingsDefaultState,
        _: NeuralModelSettingsDefaultState,
    ) -> Bool {
        true
    }
}
