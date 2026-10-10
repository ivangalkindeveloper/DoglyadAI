import SwiftUI

struct PermissionPhotoLibraryBottomSheet: View {
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
                destination: .permissionPhotoLibrary,
            ),
            title: l10n[
                .permissionPhotoLibraryTitle,
            ],
            description: l10n[
                .permissionPhotoLibraryDescription,
            ],
        )
    }
}

#Preview {
    PermissionPhotoLibraryBottomSheet()
        .previewable()
}
