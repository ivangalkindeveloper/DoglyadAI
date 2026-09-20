import Router
import SwiftUI

final class PhotoViewScreenArguments: RouteArgumentsProtocol {
    let photos: Binding<[USExaminationScanPhoto]>
    let initialPhotoID: UUID
    let subTitle: String?
    let onDelete: ((USExaminationScanPhoto) -> Void)?

    init(
        photos: Binding<[USExaminationScanPhoto]>,
        initialPhotoID: UUID,
        subTitle: String? = nil,
        onDelete: ((USExaminationScanPhoto) -> Void)? = nil
    ) {
        self.photos = photos
        self.initialPhotoID = initialPhotoID
        self.subTitle = subTitle
        self.onDelete = onDelete
    }
}
