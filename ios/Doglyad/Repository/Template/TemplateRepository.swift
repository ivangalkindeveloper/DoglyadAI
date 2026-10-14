import DoglyadDatabase
import DoglyadNetwork
import Foundation

final class TemplateRepository: TemplateRepositoryProtocol {
    private let database: DDatabaseProtocol
    private let httpClient: DHttpClientProtocol

    init(
        database: DDatabaseProtocol,
        httpClient: DHttpClientProtocol,
    ) {
        self.database = database
        self.httpClient = httpClient
    }

    func getSelectedTemplateId() async throws -> UUID? {
        database.getSelectedUSExaminationTemplateId()
    }

    func setSelectedTemplateId(
        id: UUID,
    ) async throws {
        database.setSelectedUSExaminationTemplateId(
            value: id,
        )
    }

    func clearSelectedTemplateId() async throws {
        database.removeSelectedUSExaminationTemplateId()
    }

    func getReadyMadeTemplates(
        languageCode: String,
    ) async throws -> [USExaminationReadyMadeTemplate] {
        try await httpClient.get(
            endPoint: Self.readyMadeListEndpoint,
            headers: [DHttpHeader.acceptLanguage: languageCode],
        )
    }

    func getTemplates(
        usExaminationTypesById: [String: USExaminationType],
    ) async throws -> [USExaminationTemplate] {
        try await database.examinationTemplates.fetchExaminationTemplates { dbs in
            dbs.compactMap { db in
                guard let type = usExaminationTypesById[
                    db.usExaminationTypeId,
                ] else { return nil }
                return USExaminationTemplate.fromDB(
                    db,
                    usExaminationType: type,
                )
            }
        }
    }

    func getTemplate(
        id: UUID,
        usExaminationTypesById: [String: USExaminationType],
    ) async throws -> USExaminationTemplate? {
        let templates = try await getTemplates(
            usExaminationTypesById: usExaminationTypesById,
        )
        return templates.first { $0.id == id }
    }

    func saveTemplate(
        template: USExaminationTemplate,
    ) async throws {
        try await database.examinationTemplates.upsertExaminationTemplate(
            value: template.toDB(),
        )
    }

    func deleteTemplate(
        id: UUID,
    ) async throws {
        try await database.examinationTemplates.deleteExaminationTemplate(
            id: id,
        )
    }
}

private extension TemplateRepository {
    static let readyMadeListEndpoint = "/templates/ready_made_list"
}
