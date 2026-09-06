import SwiftUI

struct PermissionSpeechBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        PermissionModuleBottomSheetView(
            viewModel: PermissionBottomSheetViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                destination: .permissionSpeech
            ),
            title: .permissionSpeechTitle,
            description: .permissionSpeechDescription
        )
    }
}

#Preview {
    PermissionSpeechBottomSheet()
        .previewable()
}
