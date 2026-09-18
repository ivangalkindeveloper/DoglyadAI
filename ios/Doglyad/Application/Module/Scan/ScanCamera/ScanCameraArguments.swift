import DoglyadCamera
import Router
import SwiftUI

final class ScanCameraArguments: RouteArgumentsProtocol {
    let cameraController: DCameraControllerFactory.Controller
    let photos: Binding<[USExaminationScanPhoto]>
    let photoMaxCount: Int

    init(
        cameraController: DCameraControllerFactory.Controller,
        photos: Binding<[USExaminationScanPhoto]>,
        photoMaxCount: Int
    ) {
        self.cameraController = cameraController
        self.photos = photos
        self.photoMaxCount = photoMaxCount
    }
}
