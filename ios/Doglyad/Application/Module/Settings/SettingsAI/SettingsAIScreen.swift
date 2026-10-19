import DoglyadUI
import Router
import SwiftUI

struct SettingsAIScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SettingsAIArguments?

    var body: some View {
        SettingsAIScreenView(
            viewModel: SettingsAIViewModel(
                container: container,
                getInitialNeuralModel: { [ultrasoundViewModel] in ultrasoundViewModel.neuralModel },
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
                getSettingsAI: { [subscriptionViewModel] in subscriptionViewModel.resolveSettingsAI() },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    try await ultrasoundViewModel.saveNeuralModel(
                        model,
                    )
                },
                onSettingsSaved: { [ultrasoundViewModel] transcriberType, transcriptParserType, isMarkdown, temperature, maxTokens in
                    try await ultrasoundViewModel.saveSettingsAI(
                        transcriberType: transcriberType,
                        transcriptParserType: transcriptParserType,
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
    SettingsAIScreen(
        arguments: nil,
    )
    .previewable()
}
