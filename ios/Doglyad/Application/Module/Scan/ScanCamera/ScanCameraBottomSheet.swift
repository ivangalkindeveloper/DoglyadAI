import DoglyadCamera
import Router
import SwiftUI

struct ScanCameraBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: ScanCameraArguments

    var body: some View {
        ScanCameraBottomSheetView(
            viewModel: ScanCameraViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    @Previewable @State var photos: [USExaminationScanPhoto] = []

    ScanCameraBottomSheet(
        arguments: ScanCameraArguments(
            cameraController: DCameraControllerFactory.make(),
            photos: $photos,
            photoMaxCount: 6
        )
    )
    .previewable()
}
