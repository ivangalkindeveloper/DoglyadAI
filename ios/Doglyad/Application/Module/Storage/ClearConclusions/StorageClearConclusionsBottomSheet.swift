import Router
import SwiftUI

struct StorageClearConclusionsBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: StorageClearConclusionsArguments?

    var body: some View {
        StorageClearConclusionsBottomSheetView(
            viewModel: StorageClearConclusionsViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    StorageClearConclusionsBottomSheet(
        arguments: nil
    )
    .previewable()
}
