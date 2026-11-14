import DoglyadDatabase
import Foundation

struct USExaminationPhotoRemarkPoint: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = .init()
    let x: Double
    let y: Double
    let title: String
    let description: String

    init(
        id: UUID = .init(),
        x: Double,
        y: Double,
        title: String,
        description: String,
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case x, y, title, description
    }
}

extension USExaminationPhotoRemarkPoint {
    static func fromDB(
        _ db: USExaminationPhotoRemarkPointDB,
    ) -> Self {
        Self(
            id: db.id,
            x: db.x,
            y: db.y,
            title: db.title,
            description: db.remarkDescription,
        )
    }

    func toDB() -> USExaminationPhotoRemarkPointDB {
        USExaminationPhotoRemarkPointDB(
            id: id,
            x: x,
            y: y,
            title: title,
            remarkDescription: description,
        )
    }
}
