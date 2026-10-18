import DoglyadDatabase
import Foundation

struct USExaminationPhotoRemarks: Codable, Equatable, Sendable {
    let photoId: UUID
    let points: [USExaminationPhotoRemarkPoint]
}

extension USExaminationPhotoRemarks {
    static func fromDB(
        _ db: USExaminationPhotoRemarksDB,
    ) -> Self {
        Self(
            photoId: db.photoId,
            points: db.points.map { USExaminationPhotoRemarkPoint.fromDB(
                $0,
            ) },
        )
    }

    func toDB() -> USExaminationPhotoRemarksDB {
        USExaminationPhotoRemarksDB(
            photoId: photoId,
            points: points.map { $0.toDB() },
        )
    }
}
