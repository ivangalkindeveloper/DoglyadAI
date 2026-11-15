import Combine
import DoglyadUI
import Foundation
import SwiftUI

@MainActor
final class PhotoViewViewModel: DModuleViewModel<any PhotoViewStateProtocol> {
    private let subtitle: String?
    private let messager: DMessager?
    private let arguments: PhotoViewArguments
    private var photoObservation: AnyCancellable?
    private var remarksReadTask: Task<Void, Never>?

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: PhotoViewArguments,
    ) {
        let initialPhotos = arguments.getPhotos()
        let selectedPhotoID = initialPhotos.contains(
            where: {
                $0.id == arguments.initialPhotoID
            },
        )
            ? arguments.initialPhotoID : (initialPhotos.first?.id ?? arguments.initialPhotoID)
        subtitle = arguments.subTitle
        self.messager = messager
        self.arguments = arguments

        super.init(
            state: PhotoViewInitialState(
                photos: initialPhotos,
                photoRemarks: arguments.getPhotoRemarks(),
                selectedPhotoID: selectedPhotoID,
                isRemarksVisible: container.initialUserSettings.isRemarksVisible,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .photoView,
            ),
        )
    }

    var isDeletionAvailable: Bool {
        arguments.onDelete != nil
    }

    var subTitle: String? {
        subtitle
    }

    func remarkPoints(
        for photoId: UUID,
    ) -> [USExaminationPhotoRemarkPoint] {
        state.photoRemarks.first {
            $0.photoId == photoId
        }?.points ?? []
    }

    override func onInit() {
        observeCurrentPhotos()
    }

    override func onReappear() {
        guard photoObservation == nil, remarksReadTask == nil, operationTask == nil else {
            return
        }
        observeCurrentPhotos()
    }

    override func onDisappear() {
        super.onDisappear()
        remarksReadTask?.cancel()
        remarksReadTask = nil
        photoObservation?.cancel()
        photoObservation = nil
    }

    func onTapBack() {
        guard !router.path.isEmpty else {
            return
        }
        cancelOperationTask()
        remarksReadTask?.cancel()
        remarksReadTask = nil
        photoObservation?.cancel()
        photoObservation = nil
        coordinator.pop()
    }

    func onPhotoSelected(
        _ photoID: UUID,
    ) {
        guard state.photos.contains(
            where: {
                $0.id == photoID
            },
        ) else {
            return
        }
        emit(
            state.copyWith(
                photos: nil,
                photoRemarks: nil,
                selectedPhotoID: photoID,
                isRemarksVisible: nil,
            ),
        )
    }

    func onTapDelete() {
        guard let onDelete = arguments.onDelete else {
            return
        }
        let current = arguments.getPhotos()
        guard let photo = current.first(
            where: {
                $0.id == self.state.selectedPhotoID
            },
        ) else {
            return
        }
        onDelete(
            photo,
        )
        synchronizePhotos(
            arguments.getPhotos(),
        )
    }

    func setRemarksVisibility(
        _ isVisible: Bool,
    ) {
        remarksReadTask?.cancel()
        remarksReadTask = nil
        performLocalOperation {
            try await self.container.userSettingsRepository.setIsRemarksVisible(
                isVisible,
            )
        } onSuccess: { _ in
            self.emit(
                self.state.copyWith(
                    photos: nil,
                    photoRemarks: nil,
                    selectedPhotoID: nil,
                    isRemarksVisible: isVisible,
                ),
            )
        } onFailure: { _ in
            self.messager?.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapRemark(
        _ point: USExaminationPhotoRemarkPoint,
    ) {
        coordinator.sheet(
            .photoRemark,
            arguments: PhotoRemarkArguments(
                title: point.title,
                description: point.description,
            ),
        )
    }

    func synchronizePhotos(
        _ updated: [USExaminationScanPhoto],
        photoRemarks: [USExaminationPhotoRemarks]? = nil,
    ) {
        let isCleared = !state.photos.isEmpty && updated.isEmpty
        let oldIndex = max(
            state.currentPage - 1,
            0,
        )
        let selectedPhotoID: UUID = if updated.isEmpty || updated.contains(
            where: {
                $0.id == state.selectedPhotoID
            },
        ) {
            state.selectedPhotoID
        } else {
            updated[
                min(
                    oldIndex,
                    updated.count - 1,
                ),
            ].id
        }
        emit(
            state.copyWith(
                photos: updated,
                photoRemarks: photoRemarks,
                selectedPhotoID: selectedPhotoID,
                isRemarksVisible: nil,
            ),
        )
        if isCleared {
            onTapBack()
        }
    }

    func fittedImageSize(
        image: UIImage,
        contentInsets: EdgeInsets,
        in viewport: CGSize,
    ) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else {
            return .zero
        }
        let availableWidth = max(
            viewport.width - contentInsets.leading - contentInsets.trailing,
            0,
        )
        let availableHeight = max(
            viewport.height - contentInsets.top - contentInsets.bottom,
            0,
        )
        let fitScale = min(
            availableWidth / image.size.width,
            availableHeight / image.size.height,
        )
        return CGSize(
            width: image.size.width * fitScale,
            height: image.size.height * fitScale,
        )
    }

    func transformed(
        transform: PhotoViewImageTransform,
        by value: SimultaneousGesture<MagnifyGesture, DragGesture>.Value?,
        imageSize: CGSize,
        viewport: CGSize,
        center: CGPoint,
    ) -> PhotoViewImageTransform {
        var result = transform
        if let pinch = value?.first {
            result = transform.zoomed(
                to: transform.scale * pinch.magnification,
                around: CGPoint(
                    x: pinch.startAnchor.x * viewport.width,
                    y: pinch.startAnchor.y * viewport.height,
                ),
                center: center,
            )
        } else if let drag = value?.second {
            result.offset.width += drag.translation.width
            result.offset.height += drag.translation.height
        }
        return result.constrained(
            imageSize: imageSize,
            viewport: viewport,
            center: center,
        )
    }

    func onDoubleTapPhoto(
        transform: PhotoViewImageTransform,
        location: CGPoint,
        imageSize: CGSize,
        viewport: CGSize,
        center: CGPoint,
    ) -> PhotoViewImageTransform {
        transform.scale > 1
            ? PhotoViewImageTransform()
            : transform.zoomed(
                to: 2.5,
                around: location,
                center: center,
            )
            .constrained(
                imageSize: imageSize,
                viewport: viewport,
                center: center,
            )
    }

    private func observeCurrentPhotos() {
        let sourcePhotos = arguments.getPhotos()
        guard !sourcePhotos.isEmpty else {
            emit(
                state.copyWith(
                    photos: sourcePhotos,
                    photoRemarks: [],
                    selectedPhotoID: nil,
                    isRemarksVisible: nil,
                ),
            )
            onTapBack()
            return
        }
        synchronizePhotos(
            sourcePhotos,
            photoRemarks: arguments.getPhotoRemarks(),
        )
        photoObservation?.cancel()
        photoObservation = arguments.observePhotoChanges? { [weak self] updatedPhotos, photoRemarks in
            self?.synchronizePhotos(
                updatedPhotos,
                photoRemarks: photoRemarks,
            )
        }
        remarksReadTask?.cancel()
        remarksReadTask = Task {
            do {
                let isVisible = try await container.userSettingsRepository.getIsRemarksVisible()
                guard !Task.isCancelled else {
                    return
                }
                emit(
                    state.copyWith(
                        photos: nil,
                        photoRemarks: nil,
                        selectedPhotoID: nil,
                        isRemarksVisible: isVisible,
                    ),
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                messager?.showUnknownError(
                    l10n: l10n,
                )
            }
        }
        lastTask = remarksReadTask
    }
}
