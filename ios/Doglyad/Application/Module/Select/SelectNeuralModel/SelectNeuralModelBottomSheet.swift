import Router
import SwiftUI

struct SelectNeuralModelBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: SelectNeuralModelArguments?

    var body: some View {
        SelectNeuralModelBottomSheetView(
            viewModel: SelectNeuralModelViewModel(
                container: container,
                router: router,
                arguments: arguments,
                subscription: subscriptionViewModel
            )
        )
    }
}

#Preview {
    SelectNeuralModelBottomSheet(
        arguments: nil
    )
    .previewable()
}
