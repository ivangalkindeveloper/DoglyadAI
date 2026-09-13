import DoglyadUI
import Router
import SwiftUI

struct ScanScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: ScanScreenArguments?

    var body: some View {
        ScanScreenView(
            viewModel: ScanViewModel(
                container: container,
                messager: messager,
                router: router,
                subscription: subscriptionViewModel,
                getTemplateForType: { [ultrasoundViewModel] typeId in
                    ultrasoundViewModel.templateIdByUSExaminationTypeId[typeId]
                },
                getNeuralModel: { [ultrasoundViewModel] in
                    ultrasoundViewModel.neuralModel
                },
                onNeuralModelSelected: { [ultrasoundViewModel] model in
                    ultrasoundViewModel.saveNeuralModel(model)
                }
            )
        )
    }
}

#Preview {
    ScanScreen(
        arguments: nil
    )
    .previewable()
}
