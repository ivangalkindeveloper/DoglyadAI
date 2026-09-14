import Router
import SwiftUI

struct ReadyMadeTemplateListScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: ReadyMadeTemplateListScreenArguments

    var body: some View {
        ReadyMadeTemplateListScreenView(
            viewModel: ReadyMadeTemplateListViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    ReadyMadeTemplateListScreen(
        arguments: ReadyMadeTemplateListScreenArguments(
            onTemplateSelected: { _ in }
        )
    )
    .previewable()
}
