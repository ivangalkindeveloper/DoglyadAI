import Router
import SwiftUI

struct TemplateDeleteBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: TemplateDeleteArguments?

    var body: some View {
        TemplateDeleteBottomSheetView(
            viewModel: TemplateDeleteViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    TemplateDeleteBottomSheet(
        arguments: nil
    )
    .previewable()
}
