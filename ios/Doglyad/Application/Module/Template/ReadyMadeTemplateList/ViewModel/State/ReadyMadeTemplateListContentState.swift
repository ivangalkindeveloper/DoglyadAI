@MainActor
final class ReadyMadeTemplateListContentState: ReadyMadeTemplateListStateProtocol, @MainActor Equatable {
    let templates: [USExaminationReadyMadeTemplate]

    init(
        templates: [USExaminationReadyMadeTemplate],
    ) {
        self.templates = templates
    }

    static func == (
        lhs: ReadyMadeTemplateListContentState,
        rhs: ReadyMadeTemplateListContentState,
    ) -> Bool {
        lhs.templates == rhs.templates
    }
}
