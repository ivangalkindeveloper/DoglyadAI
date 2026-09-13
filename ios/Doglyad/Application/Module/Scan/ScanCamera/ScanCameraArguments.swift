import Router
import SwiftUI

final class ScanCameraArguments: RouteArgumentsProtocol {
    let photos: Binding<[USExaminationScanPhoto]>
    let photoMaxCount: Int

    init(
        photos: Binding<[USExaminationScanPhoto]>,
        photoMaxCount: Int
    ) {
        self.photos = photos
        self.photoMaxCount = photoMaxCount
    }
}
