#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct PhotoViewPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any PhotoViewStateProtocol
        let photos: [USExaminationScanPhoto]

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
                    initialPhotoID: photos.first?.id ?? UUID(),
                    subTitle: "Щитовидная железа",
                    onDelete: { _ in },
                ),
            )

            model.preparePreview(
                state: state,
            )
            return PhotoViewScreenView(
                viewModel: model,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
