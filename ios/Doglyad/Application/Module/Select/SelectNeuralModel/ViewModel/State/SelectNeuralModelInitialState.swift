import Foundation

@MainActor
final class SelectNeuralModelInitialState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: SelectNeuralModelInitialState,
        _: SelectNeuralModelInitialState,
    ) -> Bool {
        true
    }
}
