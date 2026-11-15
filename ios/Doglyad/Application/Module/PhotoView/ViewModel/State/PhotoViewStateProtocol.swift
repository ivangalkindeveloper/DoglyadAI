import Foundation

@MainActor
protocol PhotoViewStateProtocol: AnyObject {
    var photos: [USExaminationScanPhoto] {
        get
    }
    var photoRemarks: [USExaminationPhotoRemarks] {
        get
    }
    var selectedPhotoID: UUID {
        get
    }
    var isRemarksVisible: Bool {
        get
    }
    var currentPage: Int {
        get
    }

    func copyWith(
        photos: [USExaminationScanPhoto]?,
        photoRemarks: [USExaminationPhotoRemarks]?,
        selectedPhotoID: UUID?,
        isRemarksVisible: Bool?,
    ) -> PhotoViewInitialState
}
