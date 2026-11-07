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
                state: PhotoViewState(),
            )
            return PhotoViewScreenView(
                viewModel: model,
            )
        }
    }
#endif
