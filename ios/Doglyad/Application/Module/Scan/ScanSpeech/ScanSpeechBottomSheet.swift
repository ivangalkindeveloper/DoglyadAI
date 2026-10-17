import DoglyadUI
import Router
import SwiftUI

struct ScanSpeechBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ScanSpeechArguments

    var body: some View {
        ScanSpeechBottomSheetView(
            viewModel: ScanSpeechViewModel(
                container: container,
                messager: messager,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.resolveNeuralModelSettings() },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                arguments: arguments,
            ),
        )
    }
}

#Preview {
    ScanSpeechBottomSheet(
        arguments: ScanSpeechArguments(
            examinationType: USExaminationType(
                id: "",
                title: "",
                contextualStrings: [],
            ),
            getCurrentValue: { _ in "" },
            onConfirm: nil,
        ),
    )
    .previewable()
}
