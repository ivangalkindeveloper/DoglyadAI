import Router

@MainActor
final class SubscriptionScreenViewModel: DViewModel {
    private let arguments: SubscriptionScreenArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SubscriptionScreenArguments?
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.subscription)
        )
    }

    func onTapBack() {
        analytics.buttonTapped(.subscriptionBack)
        coordinator.pop()
    }

    func onTapChangeType() {
        analytics.buttonTapped(
            .subscriptionChangeType,
            parameters: AnalyticsParameters([
                .subscriptionType: .string(subscription.status?.type.rawValue ?? "none"),
            ])
        )
        coordinator.screen(.subscriptionPaywall)
    }

    func onTapSupportCenter() {
        analytics.buttonTapped(.subscriptionCustomerCenter)
        coordinator.sheet(.subscriptionCustomerCenter)
    }
}
