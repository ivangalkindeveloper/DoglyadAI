#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PhotoViewPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let photos: [USExaminationScanPhoto]
        var remarks: [USExaminationPhotoRemarks] = []
        var isDeletionAvailable: Bool = true

        init(
            photos: [USExaminationScanPhoto],
            remarks: [USExaminationPhotoRemarks] = [],
            isDeletionAvailable: Bool = true,
        ) {
            self.photos = photos
            self.remarks = remarks
            self.isDeletionAvailable = isDeletionAvailable
        }

        var body: some View {
            let model = PhotoViewViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: PhotoViewArguments(
                    getPhotos: {
                        photos
                    },
                    getPhotoRemarks: {
                        remarks
                    },
                    initialPhotoID: photos.first?.id ?? UUID(),
                    subTitle: ModulePreviewFactory.examinationType.title,
                    onDelete: isDeletionAvailable ? { _ in } : nil,
                ),
            )

            model.preparePreview(
                state: PhotoViewInitialState(),
            )
            return PhotoViewScreenView(
                viewModel: model,
            )
        }
    }
#endif
