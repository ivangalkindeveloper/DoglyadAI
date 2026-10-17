import Foundation

@MainActor
final class TemplateListContentState: TemplateListStateProtocol {
    let templates: [USExaminationTemplate]

    init(
        templates: [USExaminationTemplate],
    ) {
        self.templates = templates
    }
}
