import Combine
import Foundation
import Router

@MainActor
final class SelectNeuralModelViewModel: DModuleViewModel {
    private let arguments: SelectNeuralModelArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectNeuralModelArguments?,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
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
            switch subscriptionStatus?.type {
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
