import Foundation

@MainActor
protocol SelectNeuralModelStateProtocol: AnyObject {
    var currentValue: USExaminationNeuralModel? {
        get
    }

    func copyWith(
        currentValue: USExaminationNeuralModel??,
    ) -> SelectNeuralModelInitialState
}
