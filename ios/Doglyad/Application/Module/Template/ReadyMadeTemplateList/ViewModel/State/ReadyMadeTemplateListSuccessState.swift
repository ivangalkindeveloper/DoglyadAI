@MainActor
final class ReadyMadeTemplateListSuccessState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    let templates: [USExaminationReadyMadeTemplate]

    init(
        templates: [USExaminationReadyMadeTemplate],
    ) {
        self.templates = templates
    }

    static func == (
        lhs: ReadyMadeTemplateListSuccessState,
        rhs: ReadyMadeTemplateListSuccessState,
    ) -> Bool {
        lhs.templates == rhs.templates
    }
}
