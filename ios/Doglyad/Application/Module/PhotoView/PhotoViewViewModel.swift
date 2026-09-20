import SwiftUI

@MainActor
final class PhotoViewViewModel: DViewModel {
    private let arguments: PhotoViewScreenArguments
    private var isClosing = false
    @Published private(set) var photos: [USExaminationScanPhoto]
    @Published var selectedPhotoID: UUID

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: PhotoViewScreenArguments
    ) {
        self.arguments = arguments
        let initialPhotos = arguments.photos.wrappedValue
        photos = initialPhotos
        selectedPhotoID = initialPhotos.contains(where: { $0.id == arguments.initialPhotoID })
            ? arguments.initialPhotoID : (initialPhotos.first?.id ?? arguments.initialPhotoID)
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.photoView)
        )
    }

    var currentPage: Int {
        photos.firstIndex(where: { $0.id == selectedPhotoID }).map { $0 + 1 } ?? 0
    }

    var subTitle: String? {
        arguments.subTitle
    }

    var isPhotoAvailable: Bool { !photos.isEmpty }

    var isDeleteButtonVisible: Bool {
        arguments.onDelete != nil
    }

    var sourcePhotos: [USExaminationScanPhoto] {
        arguments.photos.wrappedValue
    }

    func synchronizePhotos(_ updated: [USExaminationScanPhoto]) {
        let oldIndex = max(currentPage - 1, 0)
        photos = updated
        guard !photos.isEmpty else {
            onTapBack()
            return
        }
        if !photos.contains(where: { $0.id == selectedPhotoID }) {
            selectedPhotoID = photos[min(oldIndex, photos.count - 1)].id
        }
    }

    func onTapDelete() {
        guard let onDelete = arguments.onDelete else { return }
        let current = arguments.photos.wrappedValue
        guard let photo = current.first(where: { $0.id == selectedPhotoID }) else { return }
        onDelete(photo)
        synchronizePhotos(arguments.photos.wrappedValue)
    }

    func onTapBack() {
        guard !isClosing else { return }
        isClosing = true
        coordinator.pop()
    }

    override func onInit() {
        synchronizePhotos(arguments.photos.wrappedValue)
    }
}
