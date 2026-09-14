import Router
import SwiftUI

struct SelectTemplateBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: SelectTemplateArguments

    var body: some View {
        SelectTemplateBottomSheetView(
            viewModel: SelectTemplateViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    SelectTemplateBottomSheet(
        arguments: SelectTemplateArguments(
            onSelected: { _ in }
        )
    )
    .previewable()
}
