import DoglyadDatabase
import DoglyadNetwork
import Foundation

final class TemplateRepository: TemplateRepositoryProtocol {
    private let database: DDatabaseProtocol
    private let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol
    ) {
        self.database = database
        self.httpClient = httpClient
    }

    func getSelectedTemplateId() -> UUID? {
        database.getSelectedUSExaminationTemplateId()
    }

    func setSelectedTemplateId(
        id: UUID
    ) {
        database.setSelectedUSExaminationTemplateId(value: id)
    }

    func clearSelectedTemplateId() {
        database.removeSelectedUSExaminationTemplateId()
    }

    func getReadyMadeTemplates() async throws -> [USExaminationReadyMadeTemplate] {
        try await httpClient.get(
            endPoint: Self.readyMadeListEndpoint,
            headers: nil
        )
    }

    func getTemplates(
        usExaminationTypesById: [String: USExaminationType]
    ) async -> [USExaminationTemplate] {
        await database.examinationTemplates.fetchExaminationTemplates { dbs in
            dbs.compactMap { db in
                guard let type = usExaminationTypesById[db.usExaminationTypeId] else { return nil }
                return USExaminationTemplate.fromDB(db, usExaminationType: type)
            }
        }
    }

    func getTemplate(
        id: UUID,
        usExaminationTypesById: [String: USExaminationType]
    ) async -> USExaminationTemplate? {
        let templates = await getTemplates(usExaminationTypesById: usExaminationTypesById)
        return templates.first { $0.id == id }
    }

    func saveTemplate(
        template: USExaminationTemplate
    ) async {
        try? await database.examinationTemplates.upsertExaminationTemplate(value: template.toDB())
    }

    func deleteTemplate(
        id: UUID
    ) async {
        try? await database.examinationTemplates.deleteExaminationTemplate(id: id)
    }
}

private extension TemplateRepository {
    static let readyMadeListEndpoint = "/templates/ready_made_list"
}
