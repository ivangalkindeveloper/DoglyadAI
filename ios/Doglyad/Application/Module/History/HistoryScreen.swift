import DoglyadUI
import Router
import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: HistoryScreenArguments?

    var body: some View {
        HistoryScreenView(
            viewModel: HistoryViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    HistoryScreen(
        arguments: nil
    )
    .previewable()
}
