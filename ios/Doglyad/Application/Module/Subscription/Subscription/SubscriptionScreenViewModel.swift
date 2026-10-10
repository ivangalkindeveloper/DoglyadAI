import Router

@MainActor
final class SubscriptionScreenViewModel: DViewModel {
    private let arguments: SubscriptionScreenArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SubscriptionScreenArguments?,
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(
                .subscription,
            ),
        )
    }

    func onTapBack() {
        analytics.buttonTapped(
            .subscriptionBack,
        )
        coordinator.pop()
    }

    func onTapChangeType() {
        analytics.buttonTapped(
            .subscriptionChangeType,
            parameters: .subscription(
                type: subscription.status?.type,
            ),
        )
        coordinator.screen(
            .subscriptionPaywall,
        )
    }

    func onTapSupportCenter() {
        analytics.buttonTapped(
            .subscriptionCustomerCenter,
        )
        coordinator.sheet(
            .subscriptionCustomerCenter,
        )
    }
}
