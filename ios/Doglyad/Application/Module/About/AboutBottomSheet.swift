import SwiftUI

struct AboutBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    var body: some View {
        AboutBottomSheetView(
            viewModel: AboutViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    AboutBottomSheet()
        .previewable()
}
