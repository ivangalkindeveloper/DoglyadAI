import Combine
import DoglyadCamera
import DoglyadUI
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ScanCameraViewModel: DModuleViewModel {
    private let arguments: ScanCameraArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: ScanCameraArguments,
    ) {
        self.arguments = arguments
        _cameraController = NestedObservableObject(
            wrappedValue: arguments.cameraController,
        )
        photos = arguments.getPhotos()
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .scanCamera,
            ),
        )
    }

    @NestedObservableObject var cameraController: DCameraControllerFactory.Controller
    @Published private(set) var photos: [USExaminationScanPhoto]
    @Published private(set) var captureFrame: CGRect = .zero
    @Published private(set) var previewFrame: CGRect = .zero

    func onDisappear() {
        cameraController.stopSession()
    }

    func updateCaptureFrame(
        _ frame: CGRect,
    ) {
        captureFrame = frame
    }

    var isCaptureFrameReady: Bool {
        !captureFrame.isEmpty && !previewFrame.isEmpty && previewFrame.contains(
            captureFrame,
        )
    }

    func updatePreviewFrame(
        _ frame: CGRect,
    ) {
        previewFrame = frame
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

    func onTapPhoto(
        _ photo: USExaminationScanPhoto,
    ) {
        let getPhotos = arguments.getPhotos
        let onPhotosUpdated = arguments.onPhotosUpdated
        coordinator.dismissSheet()
        coordinator.screen(
            .photoView,
            arguments: PhotoViewArguments(
                getPhotos: getPhotos,
                initialPhotoID: photo.id,
                onDelete: { photo in
                    withAnimation {
                        var updatedPhotos = getPhotos()
                        updatedPhotos.removeAll { $0.id == photo.id }
                        onPhotosUpdated(
                            updatedPhotos,
                        )
                    }
                },
            ),
        )
    }

    func onCameraAppear() {
        cameraController.startSession()
    }

    func onTapCapture() {
        guard isCaptureAvailable, isCaptureFrameReady else { return }

        analytics.buttonTapped(
            .scanCapture,
            parameters: AnalyticsParameters(
                [
                    .itemCount: .int(
                        photos.count,
                    ),
                ],
            ),
        )
        let cropRegion = DCameraCropRegion(
            rect: captureFrame.offsetBy(
                dx: -previewFrame.minX,
                dy: -previewFrame.minY,
            ),
            previewSize: previewFrame.size,
        )
        cameraController.takePhoto(
            cropRegion: cropRegion,
        ) { [weak self] image in
            self?.onCapture(
                image,
            )
        }
    }

    func onTapDeletePhoto(
        photo: USExaminationScanPhoto,
    ) {
        guard let index = photos.firstIndex(
            of: photo,
        ) else { return }

        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters(
                [
                    .itemCount: .int(
                        photos.count,
                    ),
                ],
            ),
        )
        var updatedPhotos = photos
        updatedPhotos.remove(
            at: index,
        )
        updatePhotos(
            updatedPhotos,
        )
    }

    private func onCapture(
        _ image: UIImage,
    ) {
        guard !isPhotoFilling else { return }

        Task { [weak self] in
            let photo = await USExaminationScanPhoto.make(
                image: image,
            )
            guard let self,
                  !self.isPhotoFilling
            else { return }

            var updatedPhotos = photos
            updatedPhotos.append(
                photo,
            )
            updatePhotos(
                updatedPhotos,
            )

            if isPhotoFilling {
                coordinator.dismissSheet()
            }
        }
    }

    private func updatePhotos(
        _ photos: [USExaminationScanPhoto],
    ) {
        withAnimation {
            self.photos = photos
            arguments.onPhotosUpdated(
                photos,
            )
        }
    }
}
