import Router

final class SelectTemplateArguments: RouteArgumentsProtocol {
    let usExaminationId: String?
    let currentValue: USExaminationTemplate?
    let onSelected: (USExaminationTemplate) async throws -> Void

    init(
        usExaminationId: String? = nil,
        currentValue: USExaminationTemplate? = nil,
        onSelected: @escaping (USExaminationTemplate) async throws -> Void,
    ) {
        self.usExaminationId = usExaminationId
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
