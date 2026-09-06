import Router
import SwiftUI

struct SubscriptionScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: SubscriptionScreenArguments?

    var body: some View {
        SubscriptionScreenView(
            viewModel: SubscriptionScreenViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    SubscriptionScreen(
        arguments: nil
    )
    .previewable()
}
