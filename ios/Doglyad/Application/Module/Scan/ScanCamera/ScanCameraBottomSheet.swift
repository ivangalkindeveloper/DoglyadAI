import DoglyadCamera
import Router
import SwiftUI

struct ScanCameraBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel

    let arguments: ScanCameraArguments

    var body: some View {
        ScanCameraBottomSheetView(
            viewModel: ScanCameraViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in
                    subscriptionViewModel.observeStatus(
                        observer,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in
                    subscriptionViewModel.update(
                        status: status,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
                arguments: arguments,
            ),
        )
    }
}

#Preview {
    @Previewable @State var photos: [USExaminationScanPhoto] = []

    ScanCameraBottomSheet(
        arguments: ScanCameraArguments(
            cameraController: DCameraControllerFactory.make(),
            getPhotos: {
                photos
            },
            onPhotosUpdated: {
                photos = $0
            },
            photoMaxCount: 6,
        ),
    )
    .previewable()
}
