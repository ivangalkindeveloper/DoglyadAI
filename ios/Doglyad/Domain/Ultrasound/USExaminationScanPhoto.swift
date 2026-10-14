import DoglyadDatabase
import UIKit

struct ScanPhotoEncodingOptions {
    let resizeMaxDimension: Double
    let compressionQuality: Double
}

struct USExaminationScanPhoto: Identifiable, Equatable, Codable {
    static let thumbnailMaxDimension: CGFloat = 192
    static let thumbnailCompressionQuality: CGFloat = 0.8

    var id: UUID = .init()
    let image: UIImage
    let thumbnail: UIImage

    init(
        id: UUID = UUID(),
        image: UIImage,
        thumbnail: UIImage? = nil,
    ) {
        self.id = id
        self.image = image.uprightImage()
        self.thumbnail = thumbnail ?? self.image.thumbnail(
            maxDimension: Self.thumbnailMaxDimension,
        )
    }

    static func make(
        image: UIImage,
    ) async -> USExaminationScanPhoto {
        let thumbnail = await Task.detached(
            priority: .userInitiated,
        ) {
            image.thumbnail(
                maxDimension: Self.thumbnailMaxDimension,
            )
        }.value

        return USExaminationScanPhoto(
            image: image,
            thumbnail: thumbnail,
        )
    }

    init(
        from decoder: Decoder,
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self,
        )
        id = try container.decode(
            UUID.self,
            forKey: .id,
        )
        let data = try container.decode(
            Data.self,
            forKey: .data,
        )
        let image = UIImage(
            data: data,
        ) ?? UIImage()
        self.image = image.uprightImage()
        thumbnail = self.image.thumbnail(
            maxDimension: Self.thumbnailMaxDimension,
        )
    }

    func encode(
        to encoder: Encoder,
    ) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self,
        )
        try container.encode(
            id,
            forKey: .id,
        )

        guard let options = encoder.userInfo[
            .scanPhotoEncodingOptions,
        ] as? ScanPhotoEncodingOptions else {
            let data = image.pngData() ?? Data()
            try container.encode(
                data,
                forKey: .data,
            )
            return
        }

        let data = encodedJPEGData(
            options: options,
        ) ?? Data()
        try container.encode(
            data,
            forKey: .data,
        )
    }

    func encodedJPEGData(
        options: ScanPhotoEncodingOptions,
    ) -> Data? {
        image
            .resized(
                maxDimension: options.resizeMaxDimension,
            )
            .jpegData(
                compressionQuality: options.compressionQuality,
            )
    }

    static func == (
        lhs: Self,
        rhs: Self,
    ) -> Bool {
        lhs.id == rhs.id
    }
}

extension USExaminationScanPhoto {
    enum CodingKeys: String, CodingKey {
        case id
        case data
    }

    static func fromDB(
        _ db: USExaminationScanPhotoDB,
    ) -> USExaminationScanPhoto {
        USExaminationScanPhoto(
            id: db.id,
            image: UIImage(
                data: db.data,
            ) ?? UIImage(),
            thumbnail: db.thumbnailData.flatMap { UIImage(
                data: $0,
            ) },
        )
    }

    func toDB() -> USExaminationScanPhotoDB {
        USExaminationScanPhotoDB(
            id: id,
            data: image.pngData() ?? Data(),
            thumbnailData: thumbnail.jpegData(
                compressionQuality: Self.thumbnailCompressionQuality,
            ),
        )
    }

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
