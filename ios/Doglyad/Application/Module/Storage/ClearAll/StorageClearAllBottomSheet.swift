import Router
import SwiftUI

struct StorageClearAllBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: StorageClearAllArguments?

    var body: some View {
        StorageClearAllBottomSheetView(
            viewModel: StorageClearAllViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    StorageClearAllBottomSheet(
        arguments: nil
    )
    .previewable()
}
