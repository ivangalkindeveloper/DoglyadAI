import DoglyadUI
import SwiftUI

struct PhotoViewScreen: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscription: SubscriptionRootViewModel
    let arguments: PhotoViewArguments

    var body: some View {
        PhotoViewScreenView(
            viewModel: PhotoViewViewModel(
                container: container,
                messager: messager,
                router: router,
                getSubscriptionStatus: { [subscription] in subscription.status },
                observeSubscriptionStatus: { [subscription] observer in subscription.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscription] status in subscription.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscription] in subscription.neuralModelSettings },
                onRequestCountIncremented: { [subscription] in subscription.incrementRequestCount() },
                arguments: arguments,
            ),
        )
    }
}
