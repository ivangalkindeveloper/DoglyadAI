import Router
import SwiftUI

struct RequestLimitExceededBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: RequestLimitExceededArguments?

    var body: some View {
        RequestLimitExceededBottomSheetView(
            viewModel: RequestLimitViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    RequestLimitExceededBottomSheet(
        arguments: nil
    )
    .previewable()
}
