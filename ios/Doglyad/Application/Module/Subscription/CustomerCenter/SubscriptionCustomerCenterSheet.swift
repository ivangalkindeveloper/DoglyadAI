import Router
import SwiftUI

struct SubscriptionCustomerCenterSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: SubscriptionCustomerCenterArguments?

    var body: some View {
        SubscriptionCustomerCenterSheetView(
            viewModel: SubscriptionCustomerCenterViewModel(
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
    SubscriptionCustomerCenterSheet(
        arguments: nil
    )
    .previewable()
}
