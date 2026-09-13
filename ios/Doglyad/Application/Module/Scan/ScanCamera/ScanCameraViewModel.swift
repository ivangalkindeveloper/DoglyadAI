import DoglyadCamera
import DoglyadUI
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ScanCameraViewModel: DViewModel {
    private let arguments: ScanCameraArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: ScanCameraArguments
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.scanCamera)
        )
    }

    @NestedObservableObject var cameraController: DCameraControllerFactory.Controller = DCameraControllerFactory.make()

    var photos: [USExaminationScanPhoto] {
        arguments.photos.wrappedValue
    }

    var photoMaxCount: Int {
        arguments.photoMaxCount
    }

    private var isPhotoFilling: Bool {
        photos.count >= photoMaxCount
    }

    var isCaptureAvailable: Bool {
        cameraController.isRunning && !isPhotoFilling
    }

    override func onInit() {
        cameraController.startSession()
    }

    func onDisappear() {
        cameraController.stopSession()
    }

    func onTapCameraTurnOn() {
        guard !isPhotoFilling else { return }

        analytics.buttonTapped(.scanCameraTurnOn)
        cameraController.startSession()
    }

    func onTapCapture() {
        guard !isPhotoFilling else { return }

        analytics.buttonTapped(
            .scanCapture,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        cameraController.takePhoto { [weak self] image in
            self?.onCapture(image)
        }
    }

    func onTapDeletePhoto(
        photo: USExaminationScanPhoto
    ) {
        var photos = photos
        guard let index = photos.firstIndex(of: photo) else { return }

        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        photos.remove(at: index)
        arguments.photos.wrappedValue = photos
        objectWillChange.send()
    }

    private func onCapture(
        _ image: UIImage
    ) {
        guard !isPhotoFilling else { return }

        Task { [weak self] in
            let photo = await USExaminationScanPhoto.make(image: image)
            guard let self,
                  !self.isPhotoFilling
            else { return }

            var photos = self.photos
            photos.append(photo)
            self.arguments.photos.wrappedValue = photos
            self.objectWillChange.send()

            if self.isPhotoFilling {
                self.coordinator.dismissSheet()
            }
        }
    }
}
