import DoglyadUI
import Router
import SwiftUI

struct NeuralModelSettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: NeuralModelSettingsScreenArguments?

    var body: some View {
        NeuralModelSettingsScreenView(
            viewModel: NeuralModelSettingsViewModel(
                container: container,
                initialIsMarkdown: ultrasoundViewModel.isMarkdown,
                initialTemperature: ultrasoundViewModel.temperature,
                initialMaxTokens: ultrasoundViewModel.maxTokens,
                messager: messager,
                router: router,
                subscription: subscriptionViewModel,
                onSettingsSaved: { [ultrasoundViewModel] isMarkdown, temperature, maxTokens in
                    ultrasoundViewModel.saveNeuralModelSettings(
                        isMarkdown: isMarkdown,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )
                }
            )
        )
    }
}

#Preview {
    NeuralModelSettingsScreen(
        arguments: nil
    )
    .previewable()
}
