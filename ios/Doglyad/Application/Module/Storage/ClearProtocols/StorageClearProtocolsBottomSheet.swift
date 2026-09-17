import Router
import SwiftUI

struct StorageClearProtocolsBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: StorageClearProtocolsArguments?

    var body: some View {
        StorageClearProtocolsBottomSheetView(
            viewModel: StorageClearProtocolsViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    StorageClearProtocolsBottomSheet(
        arguments: nil
    )
    .previewable()
}
