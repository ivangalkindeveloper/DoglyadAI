import Combine
import Router
import SwiftUI

final class PhotoViewArguments: RouteArgumentsProtocol {
    let getPhotos: () -> [USExaminationScanPhoto]
    let getPhotoRemarks: () -> [USExaminationPhotoRemarks]
    let observePhotoChanges: ((@escaping ([USExaminationScanPhoto], [USExaminationPhotoRemarks]) -> Void) -> AnyCancellable)?
    let initialPhotoID: UUID
    let subTitle: String?
    let onDelete: ((USExaminationScanPhoto) -> Void)?

    init(
        getPhotos: @escaping () -> [USExaminationScanPhoto],
        getPhotoRemarks: @escaping () -> [USExaminationPhotoRemarks] = {
            []
        },
        observePhotoChanges: ((@escaping ([USExaminationScanPhoto], [USExaminationPhotoRemarks]) -> Void) -> AnyCancellable)? = nil,
        initialPhotoID: UUID,
        subTitle: String? = nil,
        onDelete: ((USExaminationScanPhoto) -> Void)? = nil,
    ) {
        self.getPhotos = getPhotos
        self.getPhotoRemarks = getPhotoRemarks
        self.observePhotoChanges = observePhotoChanges
        self.initialPhotoID = initialPhotoID
        self.subTitle = subTitle
        self.onDelete = onDelete
    }
}
