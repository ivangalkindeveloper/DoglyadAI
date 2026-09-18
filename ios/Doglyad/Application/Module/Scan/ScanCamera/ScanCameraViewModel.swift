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
        _cameraController = NestedObservableObject(wrappedValue: arguments.cameraController)
        photos = arguments.photos.wrappedValue
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.scanCamera)
        )
    }

    @NestedObservableObject var cameraController: DCameraControllerFactory.Controller
    @Published private(set) var photos: [USExaminationScanPhoto]

    var photoMaxCount: Int {
        arguments.photoMaxCount
    }

    private var isPhotoFilling: Bool {
        photos.count >= photoMaxCount
    }

    var isCaptureAvailable: Bool {
        cameraController.isRunning && !isPhotoFilling
    }

    func onCameraAppear() {
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
        guard let index = photos.firstIndex(of: photo) else { return }

        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        var updatedPhotos = photos
        updatedPhotos.remove(at: index)
        updatePhotos(updatedPhotos)
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

            var updatedPhotos = self.photos
            updatedPhotos.append(photo)
            self.updatePhotos(updatedPhotos)

            if self.isPhotoFilling {
                self.coordinator.dismissSheet()
            }
        }
    }

    private func updatePhotos(
        _ photos: [USExaminationScanPhoto]
    ) {
        withAnimation {
            self.photos = photos
            arguments.photos.wrappedValue = photos
        }
    }
}
