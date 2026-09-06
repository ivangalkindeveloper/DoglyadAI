import SwiftUI

struct PhotoLibraryPicker: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: PhotoLibraryPickerArguments

    var body: some View {
        PhotoLibraryPickerView(
            viewModel: PhotoLibraryPickerViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}
