import DoglyadUI
import Router
import SwiftUI

struct ImportMediaBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: ImportMediaArguments

    var body: some View {
        ImportMediaBottomSheetView(
            viewModel: ImportMediaViewModel(
                container: container,
                router: router,
                arguments: arguments,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    ImportMediaBottomSheet(
        arguments: ImportMediaArguments(
            onTapCamera: {},
            onTapGallery: {}
        )
    )
    .previewable()
}
