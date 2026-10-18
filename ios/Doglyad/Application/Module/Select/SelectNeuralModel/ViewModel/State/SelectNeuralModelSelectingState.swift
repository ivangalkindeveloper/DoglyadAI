import Foundation

@MainActor
final class SelectNeuralModelSelectingState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectNeuralModelSelectingState,
        _: SelectNeuralModelSelectingState,
    ) -> Bool {
        true
    }
}
