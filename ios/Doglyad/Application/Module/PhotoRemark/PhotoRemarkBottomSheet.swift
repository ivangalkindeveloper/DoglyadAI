import SwiftUI

struct PhotoRemarkBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscription: SubscriptionRootViewModel
    let arguments: PhotoRemarkArguments

    var body: some View {
        PhotoRemarkBottomSheetView(
            viewModel: PhotoRemarkViewModel(
                container: container,
                router: router,
                arguments: arguments,
                getSubscriptionStatus: { [subscription] in subscription.status },
                observeSubscriptionStatus: { [subscription] observer in subscription.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscription] status in subscription.update(
                    status: status,
                ) },
                getSettingsAI: { [subscription] in subscription.resolveSettingsAI() },
                onRequestCountIncremented: { [subscription] in subscription.incrementRequestCount() },
            ),
        )
    }
}
