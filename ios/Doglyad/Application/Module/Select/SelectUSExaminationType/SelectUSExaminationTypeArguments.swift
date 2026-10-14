import Router

final class SelectUSExaminationTypeArguments: RouteArgumentsProtocol {
    let currentValue: USExaminationType?
    let onSelected: (USExaminationType) async throws -> Void

    init(
        currentValue: USExaminationType? = nil,
        onSelected: @escaping (USExaminationType) async throws -> Void,
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
