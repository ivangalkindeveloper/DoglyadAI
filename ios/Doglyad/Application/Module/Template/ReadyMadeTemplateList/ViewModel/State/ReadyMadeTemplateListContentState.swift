@MainActor
final class ReadyMadeTemplateListContentState: ReadyMadeTemplateListStateProtocol {
    let templates: [USExaminationReadyMadeTemplate]

    init(
        templates: [USExaminationReadyMadeTemplate],
    ) {
        self.templates = templates
    }
}
