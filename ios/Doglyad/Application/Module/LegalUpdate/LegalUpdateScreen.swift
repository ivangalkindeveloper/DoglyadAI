import DoglyadUI
import Router
import SwiftUI

struct LegalUpdateScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: LegalUpdateScreenArguments?

    var body: some View {
        LegalUpdateScreenView(
            viewModel: LegalUpdateViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    LegalUpdateScreen(
        arguments: nil
    )
    .previewable()
}
