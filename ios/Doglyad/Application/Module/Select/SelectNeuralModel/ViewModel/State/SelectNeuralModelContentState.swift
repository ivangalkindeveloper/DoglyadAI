import Foundation

@MainActor
final class SelectNeuralModelContentState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectNeuralModelContentState,
        _: SelectNeuralModelContentState,
    ) -> Bool {
        true
    }
}
