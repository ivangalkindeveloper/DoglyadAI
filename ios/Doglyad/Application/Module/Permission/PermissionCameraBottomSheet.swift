import SwiftUI

struct PermissionCameraBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        PermissionModuleBottomSheetView(
            viewModel: PermissionBottomSheetViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                destination: .permissionCamera
            ),
            title: .permissionCameraTitle,
            description: .permissionCameraDescription
        )
    }
}

#Preview {
    PermissionCameraBottomSheet()
        .previewable()
}
