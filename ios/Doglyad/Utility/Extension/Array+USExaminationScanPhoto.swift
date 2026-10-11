import DoglyadDatabase
import UIKit

extension USExaminationScanPhoto {
    static func fromDraftDB(
        _ db: USExaminationDraftPhotoDB,
    ) -> USExaminationScanPhoto? {
        guard let image = UIImage(
            data: db.data,
        ) else { return nil }

        return USExaminationScanPhoto(
            id: db.id,
            image: image,
            thumbnail: db.thumbnailData.flatMap { UIImage(
                data: $0,
            ) },
        )
    }

    func toDraftDB(
        position: Int,
    ) -> USExaminationDraftPhotoDB? {
        guard let data = image.pngData() else { return nil }

        return USExaminationDraftPhotoDB(
            id: id,
            position: position,
            data: data,
            thumbnailData: thumbnail.jpegData(
                compressionQuality: Self.thumbnailCompressionQuality,
            ),
        )
    }
}

extension [USExaminationScanPhoto] {
    func toDraftDB() -> [USExaminationDraftPhotoDB] {
        enumerated().compactMap { index, photo in
            photo.toDraftDB(
                position: index,
            )
        }
    }
}
