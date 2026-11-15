import Foundation

@MainActor
final class SelectNeuralModelInitialState: SelectNeuralModelStateProtocol, @MainActor Equatable {
    let currentValue: USExaminationNeuralModel?

    init(
        currentValue: USExaminationNeuralModel? = nil,
    ) {
        self.currentValue = currentValue
    }

    func copyWith(
        currentValue: USExaminationNeuralModel?? = nil,
    ) -> SelectNeuralModelInitialState {
        SelectNeuralModelInitialState(
            currentValue: currentValue ?? self.currentValue,
        )
    }

    static func == (
        lhs: SelectNeuralModelInitialState,
        rhs: SelectNeuralModelInitialState,
    ) -> Bool {
        lhs.currentValue == rhs.currentValue
    }
}
