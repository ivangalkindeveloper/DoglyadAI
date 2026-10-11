import Router

final class ReadyMadeTemplateListArguments: RouteArgumentsProtocol {
    let onTemplateSelected: (USExaminationReadyMadeTemplate) -> Void

    init(
        onTemplateSelected: @escaping (USExaminationReadyMadeTemplate) -> Void,
    ) {
        self.onTemplateSelected = onTemplateSelected
    }
}
