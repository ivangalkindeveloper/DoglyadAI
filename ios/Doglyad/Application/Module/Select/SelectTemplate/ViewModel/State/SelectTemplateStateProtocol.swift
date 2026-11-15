import Foundation

@MainActor
protocol SelectTemplateStateProtocol: AnyObject {
    var templates: [USExaminationTemplate] {
        get
    }
    var currentTemplateID: UUID? {
        get
    }

    func copyWith(
        templates: [USExaminationTemplate]?,
        currentTemplateID: UUID??,
    ) -> SelectTemplateContentState
}
