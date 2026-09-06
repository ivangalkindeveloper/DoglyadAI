import DoglyadUI
import Router
import SwiftUI

struct StorageScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: StorageScreenArguments?

    var body: some View {
        StorageScreenView(
            viewModel: StorageViewModel(
                container: container,
                messager: messager,
                router: router,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    StorageScreen(
        arguments: nil
    )
    .previewable()
}
