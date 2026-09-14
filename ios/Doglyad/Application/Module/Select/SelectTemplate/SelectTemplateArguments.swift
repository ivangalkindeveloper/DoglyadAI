import Router

final class SelectTemplateArguments: RouteArgumentsProtocol {
    let usExaminationId: String?
    let currentValue: USExaminationTemplate?
    let onSelected: (USExaminationTemplate) -> Void

    init(
        usExaminationId: String? = nil,
        currentValue: USExaminationTemplate? = nil,
        onSelected: @escaping (USExaminationTemplate) -> Void
    ) {
        self.usExaminationId = usExaminationId
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
