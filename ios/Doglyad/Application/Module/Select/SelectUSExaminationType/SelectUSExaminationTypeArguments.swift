import Router

final class SelectUSExaminationTypeArguments: RouteArgumentsProtocol {
    let currentValue: USExaminationType?
    let onSelected: (USExaminationType) -> Void

    init(
        currentValue: USExaminationType? = nil,
        onSelected: @escaping (USExaminationType) -> Void
    ) {
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
