import DoglyadUI
import Router
import SwiftUI

struct TemplateListScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: TemplateListScreenArguments?

    var body: some View {
        TemplateListScreenView(
            viewModel: TemplateListViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    TemplateListScreen(
        arguments: nil
    )
    .previewable()
}
