import Combine
import DoglyadUI
import Foundation
import SwiftUI

@MainActor
final class PhotoViewViewModel: DModuleViewModel<any PhotoViewStateProtocol> {
    @Published var photos: [USExaminationScanPhoto]
    @Published var selectedPhotoID: UUID
    @Published private(set) var isRemarksVisible: Bool
    private let getPhotoRemarks: () -> [USExaminationPhotoRemarks]
    private let subtitle: String?
    private let getSourcePhotos: () -> [USExaminationScanPhoto]

    private let messager: DMessager?
    private let arguments: PhotoViewArguments
    private var photoObservation: AnyCancellable?
    private var isClosing = false

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: PhotoViewArguments,
    ) {
        self.messager = messager
        self.arguments = arguments

        let initialPhotos = arguments.getPhotos()
        photos = initialPhotos
        selectedPhotoID = initialPhotos.contains(
            where: { $0.id == arguments.initialPhotoID },
        )
            ? arguments.initialPhotoID : (initialPhotos.first?.id ?? arguments.initialPhotoID)
        isRemarksVisible = container.initialUserSettings.isRemarksVisible
        getPhotoRemarks = arguments.getPhotoRemarks
        subtitle = arguments.subTitle
        getSourcePhotos = arguments.getPhotos

        super.init(
            state: initialPhotos.isEmpty ? PhotoViewEmptyState() : PhotoViewContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .photoView,
            ),
        )
        photoObservation = arguments.observePhotos? { [weak self] updatedPhotos in self?.synchronizePhotos(
            updatedPhotos,
        ) }
    }

    var isDeletionAvailable: Bool { arguments.onDelete != nil }

    var currentPage: Int {
        photos.firstIndex(
            where: { $0.id == selectedPhotoID },
        ).map { $0 + 1 } ?? 0
    }

    var subTitle: String? {
        subtitle
    }

    var sourcePhotos: [USExaminationScanPhoto] {
        getSourcePhotos()
    }

    func remarkPoints(
        for photoId: UUID,
    ) -> [USExaminationPhotoRemarkPoint] {
        getPhotoRemarks().first { $0.photoId == photoId }?.points ?? []
    }

    override func onInit() {
        synchronizePhotos(
            arguments.getPhotos(),
        )
        handle {
            try await self.container.userSettingsRepository.getIsRemarksVisible()
        } onMainSuccess: { self.isRemarksVisible = $0 } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapBack() {
        guard !isClosing else { return }
        isClosing = true
        coordinator.pop()
    }

    func onPhotoSelected(
        _ photoID: UUID,
    ) {
        guard photos.contains(
            where: { $0.id == photoID },
        ) else { return }
        selectedPhotoID = photoID
    }

    func onTapDelete() {
        guard let onDelete = arguments.onDelete else { return }
        let current = arguments.getPhotos()
        guard let photo = current.first(
            where: { $0.id == self.selectedPhotoID },
        ) else { return }
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
        handle {
            try await self.container.userSettingsRepository.setIsRemarksVisible(
                isVisible,
            )
        } onMainSuccess: { self.isRemarksVisible = isVisible } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
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
    ) {
        let oldIndex = max(
            currentPage - 1,
            0,
        )
        photos = updated
        guard !photos.isEmpty else {
            emit(
                PhotoViewEmptyState(),
            )
            onTapBack()
            return
        }
        if !photos.contains(
            where: { $0.id == self.selectedPhotoID },
        ) {
            selectedPhotoID = photos[
                min(
                    oldIndex,
                    photos.count - 1,
                ),
            ].id
        }
        emit(
            PhotoViewContentState(),
        )
    }

    func fittedImageSize(
        image: UIImage,
        contentInsets: EdgeInsets,
        in viewport: CGSize,
    ) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
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
}
