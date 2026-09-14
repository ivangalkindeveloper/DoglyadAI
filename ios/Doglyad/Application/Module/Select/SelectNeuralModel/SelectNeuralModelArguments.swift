import Router

final class SelectNeuralModelArguments: RouteArgumentsProtocol {
    let currentValue: USExaminationNeuralModel?
    let onSelected: (USExaminationNeuralModel) -> Void

    init(
        currentValue: USExaminationNeuralModel? = nil,
        onSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
