import Foundation
import Router

@MainActor
final class SelectNeuralModelViewModel: DViewModel {
    private let arguments: SelectNeuralModelArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectNeuralModelArguments?,
        subscription: SubscriptionViewModel
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    var models: [USExaminationNeuralModel] {
        container.usExaminationNeuralModels
    }

    func isSelected(_ model: USExaminationNeuralModel) -> Bool {
        arguments?.currentValue == model
    }

    func isProBadgeVisible(for model: USExaminationNeuralModel) -> Bool {
        switch model.entitlement {
        case .base:
            return false
        case .pro:
            switch subscription.status?.type {
            case .some(.pro):
                return false
            case .some(.base), .none:
                return true
            }
        }
    }

    func isComingSoonBadgeVisible(for model: USExaminationNeuralModel) -> Bool {
        switch model.accessibility {
        case .available, .unavailable:
            return false
        case .comingSoon:
            return true
        }
    }

    func isSelectionEnabled(for model: USExaminationNeuralModel) -> Bool {
        switch model.accessibility {
        case .available:
            return true
        case .comingSoon, .unavailable:
            return false
        }
    }

    func onModelTap(_ model: USExaminationNeuralModel) {
        coordinator.selectNeuralModel(model) { [weak self] model in
            self?.arguments?.onSelected(model)
        }
    }
}
