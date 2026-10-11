import Router

final class TemplateAddArguments: RouteArgumentsProtocol {
    let onTemplatesChanged: (() -> Void)?
    let onAddSuccess: ((USExaminationTemplate) -> Void)?

    init(
        onTemplatesChanged: (() -> Void)? = nil,
        onAddSuccess: ((USExaminationTemplate) -> Void)? = nil,
    ) {
        self.onTemplatesChanged = onTemplatesChanged
        self.onAddSuccess = onAddSuccess
    }
}
