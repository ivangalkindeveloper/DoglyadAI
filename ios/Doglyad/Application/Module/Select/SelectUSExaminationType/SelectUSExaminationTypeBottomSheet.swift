import Router
import SwiftUI

struct SelectUSExaminationTypeBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: SelectUSExaminationTypeArguments?

    var body: some View {
        SelectUSExaminationTypeBottomSheetView(
            viewModel: SelectUSExaminationTypeViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    SelectUSExaminationTypeBottomSheet(
        arguments: nil
    )
    .previewable()
}
