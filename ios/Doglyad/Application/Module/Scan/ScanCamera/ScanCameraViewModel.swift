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
    @Published private(set) var captureFrame: CGRect = .zero
    @Published private(set) var previewFrame: CGRect = .zero

    func updateCaptureFrame(_ frame: CGRect) {
        captureFrame = frame
    }

    func updatePreviewFrame(_ frame: CGRect) {
        previewFrame = frame
    }

    var isCaptureFrameReady: Bool {
        !captureFrame.isEmpty && !previewFrame.isEmpty && previewFrame.contains(captureFrame)
    }

    func onTapPhoto(_ photo: USExaminationScanPhoto) {
        let photos = arguments.photos
        coordinator.dismissSheet()
        coordinator.screen(
            .photoView,
            arguments: PhotoViewScreenArguments(
                photos: photos,
                initialPhotoID: photo.id,
                onDelete: { photo in
                    withAnimation {
                        photos.wrappedValue.removeAll { $0.id == photo.id }
                    }
                }
            )
        )
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

    func onCameraAppear() {
        cameraController.startSession()
    }

    func onDisappear() {
        cameraController.stopSession()
    }

    func onTapCapture() {
        guard isCaptureAvailable, isCaptureFrameReady else { return }

        analytics.buttonTapped(
            .scanCapture,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        let cropRegion = DCameraCropRegion(
            rect: captureFrame.offsetBy(dx: -previewFrame.minX, dy: -previewFrame.minY),
            previewSize: previewFrame.size
        )
        cameraController.takePhoto(cropRegion: cropRegion) { [weak self] image in
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
