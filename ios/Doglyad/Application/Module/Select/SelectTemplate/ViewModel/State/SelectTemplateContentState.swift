import Foundation

@MainActor
final class SelectTemplateContentState: SelectTemplateStateProtocol, @MainActor Equatable {
    let templates: [USExaminationTemplate]
    let currentTemplateID: UUID?

    init(
        templates: [USExaminationTemplate] = [],
        currentTemplateID: UUID? = nil,
    ) {
        self.templates = templates
        self.currentTemplateID = currentTemplateID
    }

    func copyWith(
        templates: [USExaminationTemplate]? = nil,
        currentTemplateID: UUID?? = nil,
    ) -> SelectTemplateContentState {
        SelectTemplateContentState(
            templates: templates ?? self.templates,
            currentTemplateID: currentTemplateID ?? self.currentTemplateID,
        )
    }

    static func == (
        lhs: SelectTemplateContentState,
        rhs: SelectTemplateContentState,
    ) -> Bool {
        lhs.templates == rhs.templates && lhs.currentTemplateID == rhs.currentTemplateID
    }
}
