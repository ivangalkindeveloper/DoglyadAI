import Foundation

protocol TemplateRepositoryProtocol: AnyObject {
    func getSelectedTemplateId() -> UUID?

    func setSelectedTemplateId(id: UUID)

    func clearSelectedTemplateId()

    func getReadyMadeTemplates() async throws -> [USExaminationReadyMadeTemplate]

    func getTemplates(
        usExaminationTypesById: [String: USExaminationType]
    ) async -> [USExaminationTemplate]

    func getTemplate(
        id: UUID,
        usExaminationTypesById: [String: USExaminationType]
    ) async -> USExaminationTemplate?

    func saveTemplate(template: USExaminationTemplate) async

    func deleteTemplate(id: UUID) async
}
