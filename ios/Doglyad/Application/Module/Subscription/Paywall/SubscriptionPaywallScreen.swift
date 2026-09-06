import Router
import SwiftUI

struct SubscriptionPaywallScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: SubscriptionPaywallArguments?

    var body: some View {
        SubscriptionPaywallScreenView(
            viewModel: SubscriptionPaywallViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments,
                onRefreshStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                }
            )
        )
    }
}

#Preview {
    SubscriptionPaywallScreen(
        arguments: nil
    )
    .previewable()
}
