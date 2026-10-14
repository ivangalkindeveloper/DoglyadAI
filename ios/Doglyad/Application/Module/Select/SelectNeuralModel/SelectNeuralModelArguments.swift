import Router

final class SelectNeuralModelArguments: RouteArgumentsProtocol {
    let currentValue: USExaminationNeuralModel?
    let onSelected: (USExaminationNeuralModel) async throws -> Void

    init(
        currentValue: USExaminationNeuralModel? = nil,
        onSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
