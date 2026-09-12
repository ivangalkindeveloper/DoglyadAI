import DoglyadDatabase
import UIKit

struct ScanPhotoEncodingOptions {
    let resizeMaxDimension: Double
    let compressionQuality: Double
}

extension CodingUserInfoKey {
    static let scanPhotoEncodingOptions = CodingUserInfoKey(rawValue: "scanPhotoEncodingOptions")!
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
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.image = image
        self.thumbnail = thumbnail ?? image.thumbnail(maxDimension: Self.thumbnailMaxDimension)
    }

    static func make(
        image: UIImage
    ) async -> USExaminationScanPhoto {
        let thumbnail = await Task.detached(priority: .userInitiated) {
            image.thumbnail(maxDimension: Self.thumbnailMaxDimension)
        }.value

        return USExaminationScanPhoto(
            image: image,
            thumbnail: thumbnail
        )
    }

    init(
        from decoder: Decoder
    ) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        let data = try container.decode(Data.self, forKey: .data)
        let image = UIImage(data: data) ?? UIImage()
        self.image = image
        thumbnail = image.thumbnail(maxDimension: Self.thumbnailMaxDimension)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        guard let options = encoder.userInfo[.scanPhotoEncodingOptions] as? ScanPhotoEncodingOptions else {
            let data = image.pngData() ?? Data()
            try container.encode(data, forKey: .data)
            return
        }

        let data = encodedJPEGData(options: options) ?? Data()
        try container.encode(data, forKey: .data)
    }

    func encodedJPEGData(
        options: ScanPhotoEncodingOptions
    ) -> Data? {
        image
            .resized(maxDimension: options.resizeMaxDimension)
            .jpegData(compressionQuality: options.compressionQuality)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

private extension USExaminationScanPhoto {
    enum CodingKeys: String, CodingKey {
        case data
    }
}

extension USExaminationScanPhoto {
    static func fromDB(
        _ db: USExaminationScanPhotoDB
    ) -> USExaminationScanPhoto {
        USExaminationScanPhoto(
            id: db.id,
            image: UIImage(data: db.data) ?? UIImage(),
            thumbnail: db.thumbnailData.flatMap { UIImage(data: $0) }
        )
    }

    func toDB() -> USExaminationScanPhotoDB {
        USExaminationScanPhotoDB(
            id: id,
            data: image.pngData() ?? Data(),
            thumbnailData: thumbnail.jpegData(
                compressionQuality: Self.thumbnailCompressionQuality
            )
        )
    }
}
