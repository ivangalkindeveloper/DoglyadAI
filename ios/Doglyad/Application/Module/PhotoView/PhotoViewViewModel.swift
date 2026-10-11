import Combine
import SwiftUI

@MainActor
final class PhotoViewViewModel: DModuleViewModel {
    private let arguments: PhotoViewArguments
    private var photoObservation: AnyCancellable?
    private var isClosing = false
    @Published private(set) var photos: [USExaminationScanPhoto]
    @Published var selectedPhotoID: UUID
    @Published private(set) var isRemarksVisible: Bool

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: PhotoViewArguments,
    ) {
        self.arguments = arguments
        isRemarksVisible = container.userSettingsRepository.getIsRemarksVisible()
        let initialPhotos = arguments.getPhotos()
        photos = initialPhotos
        selectedPhotoID = initialPhotos.contains(
            where: { $0.id == arguments.initialPhotoID },
        )
            ? arguments.initialPhotoID : (initialPhotos.first?.id ?? arguments.initialPhotoID)
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .photoView,
            ),
        )
        photoObservation = arguments.observePhotos? { [weak self] photos in self?.synchronizePhotos(
            photos,
        ) }
    }

    var currentPage: Int {
        photos.firstIndex(
            where: { $0.id == selectedPhotoID },
        ).map { $0 + 1 } ?? 0
    }

    var subTitle: String? {
        arguments.subTitle
    }

    var isPhotoAvailable: Bool { !photos.isEmpty }

    var isDeleteButtonVisible: Bool {
        arguments.onDelete != nil
    }

    var isRemarksToggleVisible: Bool { !remarkPoints(
        for: selectedPhotoID,
    ).isEmpty }

    var sourcePhotos: [USExaminationScanPhoto] {
        arguments.getPhotos()
    }

    override func onInit() {
        synchronizePhotos(
            arguments.getPhotos(),
        )
    }

    func onTapBack() {
        guard !isClosing else { return }
        isClosing = true
        coordinator.pop()
    }

    func onTapDelete() {
        guard let onDelete = arguments.onDelete else { return }
        let current = arguments.getPhotos()
        guard let photo = current.first(
            where: { $0.id == selectedPhotoID },
        ) else { return }
        onDelete(
            photo,
        )
        synchronizePhotos(
            arguments.getPhotos(),
        )
    }

    func remarkPoints(
        for photoId: UUID,
    ) -> [USExaminationPhotoRemarkPoint] {
        arguments.getPhotoRemarks().first { $0.photoId == photoId }?.points ?? []
    }

    func setRemarksVisibility(
        _ isVisible: Bool,
    ) {
        isRemarksVisible = isVisible
        container.userSettingsRepository.setIsRemarksVisible(
            isVisible,
        )
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
            onTapBack()
            return
        }
        if !photos.contains(
            where: { $0.id == selectedPhotoID },
        ) {
            selectedPhotoID = photos[
                min(
                    oldIndex,
                    photos.count - 1,
                ),
            ].id
        }
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
