import DoglyadCamera
import Router
import SwiftUI

final class ScanCameraArguments: RouteArgumentsProtocol {
    let cameraController: DCameraControllerFactory.Controller
    let getPhotos: () -> [USExaminationScanPhoto]
    let onPhotosUpdated: ([USExaminationScanPhoto]) -> Void
    let photoMaxCount: Int

    init(
        cameraController: DCameraControllerFactory.Controller,
        getPhotos: @escaping () -> [USExaminationScanPhoto],
        onPhotosUpdated: @escaping ([USExaminationScanPhoto]) -> Void,
        photoMaxCount: Int,
    ) {
        self.cameraController = cameraController
        self.getPhotos = getPhotos
        self.onPhotosUpdated = onPhotosUpdated
        self.photoMaxCount = photoMaxCount
    }
}
