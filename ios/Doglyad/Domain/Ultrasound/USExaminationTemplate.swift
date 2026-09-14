import DoglyadDatabase
import Foundation

struct USExaminationTemplate: Codable, Identifiable, Equatable {
    var id: UUID = .init()
    let usExaminationType: USExaminationType
    let name: String
    let content: String

    init(
        id: UUID = UUID(),
        usExaminationType: USExaminationType,
        name: String,
        content: String
    ) {
        self.id = id
        self.usExaminationType = usExaminationType
        self.name = name
        self.content = content
    }
}

extension USExaminationTemplate {
    static func fromDB(
        _ db: USExaminationTemplateDB,
        usExaminationType: USExaminationType
    ) -> USExaminationTemplate {
        USExaminationTemplate(
            id: db.id,
            usExaminationType: usExaminationType,
            name: db.name,
            content: db.content
        )
    }

    func toDB() -> USExaminationTemplateDB {
        USExaminationTemplateDB(
            id: id,
            usExaminationTypeId: usExaminationType.id,
            name: name,
            content: content
        )
    }
}
