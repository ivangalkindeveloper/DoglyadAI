import Foundation

@MainActor
final class SelectNeuralModelSelectionLoadingState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    static func == (
        _: SelectNeuralModelSelectionLoadingState,
        _: SelectNeuralModelSelectionLoadingState,
    ) -> Bool {
        true
    }
}
