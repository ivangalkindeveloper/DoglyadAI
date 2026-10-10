import Foundation
import Router

@MainActor
final class SelectNeuralModelViewModel: DViewModel {
    private let arguments: SelectNeuralModelArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectNeuralModelArguments?,
        subscription: SubscriptionViewModel,
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(
                .selectNeuralModel,
            ),
            analyticsParameters: .neuralModelSelection(
                currentModelId: arguments?.currentValue?.id,
            ),
        )
    }

    var models: [USExaminationNeuralModel] {
        container.usExaminationNeuralModels
    }

    func isSelected(
        _ model: USExaminationNeuralModel,
    ) -> Bool {
        arguments?.currentValue == model
    }

    func isProBadgeVisible(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.entitlement {
        case .base:
            false
        case .pro:
            switch subscription.status?.type {
            case .some(
                .pro,
            ):
                false
            case .some(
                .base,
            ), .none:
                true
            }
        }
    }

    func isComingSoonBadgeVisible(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.accessibility {
        case .available, .unavailable:
            false
        case .comingSoon:
            true
        }
    }

    func isSelectionEnabled(
        for model: USExaminationNeuralModel,
    ) -> Bool {
        switch model.accessibility {
        case .available:
            true
        case .comingSoon, .unavailable:
            false
        }
    }

    func onModelTap(
        _ model: USExaminationNeuralModel,
    ) {
        analytics.buttonTapped(
            .selectNeuralModel,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        model.id,
                    ),
                ],
            ),
        )
        coordinator.selectNeuralModel(
            model,
        ) { [weak self] model in
            self?.arguments?.onSelected(
                model,
            )
        }
    }
}
