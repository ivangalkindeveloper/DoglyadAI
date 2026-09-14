import DoglyadDatabase
import Foundation

final class TemplateRepository: TemplateRepositoryProtocol {
    private let database: DDatabaseProtocol

    init(
        database: DDatabaseProtocol
    ) {
        self.database = database
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
