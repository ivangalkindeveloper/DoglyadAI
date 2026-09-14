import Router

final class ReadyMadeTemplateListScreenArguments: RouteArgumentsProtocol {
    let onTemplateSelected: (USExaminationReadyMadeTemplate) -> Void

    init(
        onTemplateSelected: @escaping (USExaminationReadyMadeTemplate) -> Void
    ) {
        self.onTemplateSelected = onTemplateSelected
    }
}
