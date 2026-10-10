import SwiftUI

struct PermissionCameraBottomSheet: View {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        PermissionModuleBottomSheetView(
            viewModel: PermissionBottomSheetViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                destination: .permissionCamera,
            ),
            title: l10n[
                .permissionCameraTitle,
            ],
            description: l10n[
                .permissionCameraDescription,
            ],
        )
    }
}

#Preview {
    PermissionCameraBottomSheet()
        .previewable()
}
