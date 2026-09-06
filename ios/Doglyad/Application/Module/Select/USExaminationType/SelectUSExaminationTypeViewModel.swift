import Foundation

@MainActor
final class SelectUSExaminationTypeViewModel: DViewModel {
    private let arguments: SelectUSExaminationTypeArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SelectUSExaminationTypeArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.selectUSExaminationType),
            analyticsParameters: AnalyticsParameters([
                .hasCurrentValue: .bool(arguments?.currentValue != nil),
            ])
        )
    }

    var types: [USExaminationType] {
        container.usExaminationTypes
    }

    func isSelected(_ type: USExaminationType) -> Bool {
        arguments?.currentValue == type
    }

    func onTypeTap(_ type: USExaminationType) {
        analytics.buttonTapped(.selectUSExaminationType)
        coordinator.dismissSheet()
        arguments?.onSelected(type)
    }
}
