import DoglyadUI
import Router
import SwiftUI

struct NewVersionScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: NewVersionScreenArguments?

    var body: some View {
        NewVersionScreenView(
            viewModel: NewVersionViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    NewVersionScreen(
        arguments: nil
    )
    .previewable()
}
