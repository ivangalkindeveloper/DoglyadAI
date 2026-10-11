import DoglyadUI
import Router
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SettingsArguments?

    var body: some View {
        SettingsScreenView(
            viewModel: SettingsViewModel(
                container: container,
                router: router,
                getInitialNeuralModel: { [ultrasoundViewModel] in ultrasoundViewModel.neuralModel },
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    ultrasoundViewModel.saveNeuralModel(
                        model,
                    )
                },
            ),
        )
    }
}

#Preview {
    SettingsScreen(
        arguments: nil,
    )
    .previewable()
}
