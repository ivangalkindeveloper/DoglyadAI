import Foundation

protocol TemplateRepositoryProtocol: AnyObject {
    func getSelectedTemplateId() async throws -> UUID?

    func setSelectedTemplateId(
        id: UUID,
    ) async throws

    func clearSelectedTemplateId() async throws

    func getReadyMadeTemplates(
        languageCode: String,
    ) async throws -> [USExaminationReadyMadeTemplate]

    func getTemplates(
        usExaminationTypesById: [String: USExaminationType],
    ) async throws -> [USExaminationTemplate]

    func getTemplate(
        id: UUID,
        usExaminationTypesById: [String: USExaminationType],
    ) async throws -> USExaminationTemplate?

    func saveTemplate(
        template: USExaminationTemplate,
    ) async throws

    func deleteTemplate(
        id: UUID,
    ) async throws
}
