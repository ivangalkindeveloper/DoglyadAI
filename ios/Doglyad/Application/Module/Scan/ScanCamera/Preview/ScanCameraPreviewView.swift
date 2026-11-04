#if DEBUG
    import Combine
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    struct ScanCameraPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any ScanCameraStateProtocol

        var body: some View {
            let model = ScanCameraViewModel(
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
                arguments: ScanCameraArguments(
                    cameraController: DCameraControllerFactory.make(),
                    getPhotos: {
                        ModulePreviewFactory.photos
                    },
                    onPhotosUpdated: { _ in },
                    photoMaxCount: 6,
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                ScanCameraBottomSheetView(
                    viewModel: model,
                )
            }
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
