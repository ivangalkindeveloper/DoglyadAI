import DoglyadUI
import Router
import SwiftUI

struct NeuralModelSettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: NeuralModelSettingsArguments?

    var body: some View {
        NeuralModelSettingsScreenView(
            viewModel: NeuralModelSettingsViewModel(
                container: container,
                getInitialIsMarkdown: { [ultrasoundViewModel] in ultrasoundViewModel.isMarkdown },
                getInitialTemperature: { [ultrasoundViewModel] in ultrasoundViewModel.temperature },
                getInitialMaxTokens: { [ultrasoundViewModel] in ultrasoundViewModel.maxTokens },
                messager: messager,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                onSettingsSaved: { [ultrasoundViewModel] isMarkdown, temperature, maxTokens in
                    ultrasoundViewModel.saveNeuralModelSettings(
                        isMarkdown: isMarkdown,
                        temperature: temperature,
                        maxTokens: maxTokens,
                    )
                },
            ),
        )
    }
}

#Preview {
    NeuralModelSettingsScreen(
        arguments: nil,
    )
    .previewable()
}
