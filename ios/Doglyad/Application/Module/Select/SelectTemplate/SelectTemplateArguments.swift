import Router

final class SelectTemplateArguments: RouteArgumentsProtocol {
    let templates: [USExaminationTemplate]
    let currentValue: USExaminationTemplate?
    let onSelected: (USExaminationTemplate) async throws -> Void

    init(
        templates: [USExaminationTemplate],
        currentValue: USExaminationTemplate? = nil,
        onSelected: @escaping (USExaminationTemplate) async throws -> Void,
    ) {
        self.templates = templates
        self.currentValue = currentValue
        self.onSelected = onSelected
    }
}
