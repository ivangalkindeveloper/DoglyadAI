import Router

final class TemplateAddArguments: RouteArgumentsProtocol {
    let onTemplatesChanged: (() -> Void)?
    let onAddSuccess: ((USExaminationTemplate) async throws -> Void)?

    init(
        onTemplatesChanged: (() -> Void)? = nil,
        onAddSuccess: ((USExaminationTemplate) async throws -> Void)? = nil,
    ) {
        self.onTemplatesChanged = onTemplatesChanged
        self.onAddSuccess = onAddSuccess
    }
}
