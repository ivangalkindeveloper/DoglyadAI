import SwiftUI

struct PhotoViewScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscription: SubscriptionViewModel
    let arguments: PhotoViewScreenArguments

    var body: some View {
        PhotoViewScreenView(
            viewModel: PhotoViewViewModel(
                container: container,
                router: router,
                subscription: subscription,
                arguments: arguments
            )
        )
    }
}
