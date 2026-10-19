import Combine
import DoglyadCamera
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ScanCameraViewModel: DModuleViewModel<any ScanCameraStateProtocol> {
    @NestedObservableObject var cameraController: DCameraControllerFactory.Controller

    @Published var photos: [USExaminationScanPhoto]

    @Published var captureFrame: CGRect = .zero

    @Published var previewFrame: CGRect = .zero

    let photoMaxCount: Int

    private let arguments: ScanCameraArguments
    private var cameraObservation: AnyCancellable?
    private var presentationID: UUID?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: ScanCameraArguments,
    ) {
        self.arguments = arguments

        _cameraController = NestedObservableObject(
            wrappedValue: arguments.cameraController,
        )
        photos = arguments.getPhotos()
        photoMaxCount = arguments.photoMaxCount

        super.init(
            state: ScanCameraPreparingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .scanCamera,
            ),
        )
        _ = cameraController
    }

    var isCaptureFrameReady: Bool {
        !captureFrame.isEmpty && !previewFrame.isEmpty && previewFrame.contains(
            captureFrame,
        )
    }

    func onDisappear() {
        presentationID = nil
        cameraObservation?.cancel()
        cameraObservation = nil
        cameraController.stopSession()
        emit(
            ScanCameraStoppedState(),
        )
    }

    func onCameraAppear() {
        guard presentationID == nil else { return }
        presentationID = UUID()
        observeCamera()
        cameraController.startSession()
        refreshCameraState()
    }

    func updateCaptureFrame(
        _ frame: CGRect,
    ) {
        captureFrame = frame
    }

    func updatePreviewFrame(
        _ frame: CGRect,
    ) {
        previewFrame = frame
    }

    func onTapPhoto(
        _ photo: USExaminationScanPhoto,
    ) {
        guard presentationID != nil else { return }
        let getPhotos = arguments.getPhotos
        let onPhotosUpdated = arguments.onPhotosUpdated
        presentationID = nil
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

    func onTapCapture() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanCameraReadyState: break
        default: return
        }
        guard isCaptureFrameReady, photos.count < photoMaxCount else { return }
        emit(
            ScanCameraCapturingState(),
        )

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
        guard let id = presentationID else { return }
        guard photos.count < photoMaxCount else { return }
        emit(
            ScanCameraCapturingState(),
        )
        Task { [weak self] in
            let photo = await USExaminationScanPhoto.make(
                image: image,
            )
            guard let self, presentationID == id,
                  photos.count < self.photoMaxCount
            else { return }

            var updatedPhotos = photos
            updatedPhotos.append(
                photo,
            )
            updatePhotos(
                updatedPhotos,
            )

            emit(
                ScanCameraReadyState(),
            )
            refreshCameraState()
            if photos.count >= photoMaxCount {
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

    private func observeCamera() {
        cameraObservation = cameraController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshCameraState() }
        }
    }

    private func refreshCameraState() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanCameraCapturingState: return
        default: break
        }

        guard photos.count < photoMaxCount else { emit(
            ScanCameraReadyState(),
        )
        return
        }
        switch (cameraController.isLoading, cameraController.isCapturing, cameraController.isRunning) {
        case (true, _, _): emit(
                ScanCameraPreparingState(),
            )
        case (false, true, _): emit(
                ScanCameraCapturingState(),
            )
        case (false, false, true): emit(
                ScanCameraReadyState(),
            )
        case (false, false, false): emit(
                ScanCameraStoppedState(),
            )
        }
    }
}
