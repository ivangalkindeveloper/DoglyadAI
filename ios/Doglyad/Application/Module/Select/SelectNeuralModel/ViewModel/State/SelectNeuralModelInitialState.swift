import Foundation

@MainActor
final class SelectNeuralModelInitialState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectNeuralModelInitialState,
        _: SelectNeuralModelInitialState,
    ) -> Bool {
        true
    }
}
