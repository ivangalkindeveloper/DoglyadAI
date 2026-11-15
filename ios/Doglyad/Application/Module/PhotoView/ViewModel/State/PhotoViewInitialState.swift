import Foundation

@MainActor
final class PhotoViewInitialState: PhotoViewStateProtocol, @MainActor Equatable {
    let photos: [USExaminationScanPhoto]
    let photoRemarks: [USExaminationPhotoRemarks]
    let selectedPhotoID: UUID
    let isRemarksVisible: Bool

    init(
        photos: [USExaminationScanPhoto],
        photoRemarks: [USExaminationPhotoRemarks],
        selectedPhotoID: UUID,
        isRemarksVisible: Bool,
    ) {
        self.photos = photos
        self.photoRemarks = photoRemarks
        self.selectedPhotoID = selectedPhotoID
        self.isRemarksVisible = isRemarksVisible
    }

    var currentPage: Int {
        photos.firstIndex(
            where: {
                $0.id == selectedPhotoID
            },
        ).map {
            $0 + 1
        } ?? 0
    }

    func copyWith(
        photos: [USExaminationScanPhoto]? = nil,
        photoRemarks: [USExaminationPhotoRemarks]? = nil,
        selectedPhotoID: UUID? = nil,
        isRemarksVisible: Bool? = nil,
    ) -> PhotoViewInitialState {
        PhotoViewInitialState(
            photos: photos ?? self.photos,
            photoRemarks: photoRemarks ?? self.photoRemarks,
            selectedPhotoID: selectedPhotoID ?? self.selectedPhotoID,
            isRemarksVisible: isRemarksVisible ?? self.isRemarksVisible,
        )
    }

    static func == (
        lhs: PhotoViewInitialState,
        rhs: PhotoViewInitialState,
    ) -> Bool {
        lhs.selectedPhotoID == rhs.selectedPhotoID
            && lhs.photoRemarks == rhs.photoRemarks
            && lhs.isRemarksVisible == rhs.isRemarksVisible
            && lhs.photos.elementsEqual(
                rhs.photos,
            ) {
                $0.id == $1.id && $0.image.isEqual(
                    $1.image,
                ) && $0.thumbnail.isEqual(
                    $1.thumbnail,
                )
            }
    }
}
