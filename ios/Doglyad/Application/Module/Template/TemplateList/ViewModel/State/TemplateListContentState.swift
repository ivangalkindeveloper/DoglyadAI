import Foundation

@MainActor
final class TemplateListContentState: TemplateListStateProtocol, @MainActor Equatable {
    let templates: [USExaminationTemplate]

    init(
        templates: [USExaminationTemplate],
    ) {
        self.templates = templates
    }

    static func == (
        lhs: TemplateListContentState,
        rhs: TemplateListContentState,
    ) -> Bool {
        lhs.templates == rhs.templates
    }
}
