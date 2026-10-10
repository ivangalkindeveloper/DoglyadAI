import DoglyadUI
import Router
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: SettingsScreenArguments?

    var body: some View {
        SettingsScreenView(
            viewModel: SettingsViewModel(
                container: container,
                router: router,
                initialNeuralModel: ultrasoundViewModel.neuralModel,
                subscription: subscriptionViewModel,
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
