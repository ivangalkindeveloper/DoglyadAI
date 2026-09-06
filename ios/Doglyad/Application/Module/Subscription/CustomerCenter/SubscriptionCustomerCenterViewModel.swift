@MainActor
final class SubscriptionCustomerCenterViewModel: DViewModel {
    private let arguments: SubscriptionCustomerCenterArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SubscriptionCustomerCenterArguments?,
        onRefreshStatus: @escaping () async -> Void
    ) {
        self.arguments = arguments
        self.onRefreshStatus = onRefreshStatus
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.subscriptionCustomerCenter)
        )
    }

    func onRestoreCompleted() {
        analytics.actionCompleted(.subscriptionCustomerCenterRestoreCompleted)
        Task {
            await onRefreshStatus()
        }
    }

    func onRestoreStarted() {
        analytics.buttonTapped(.subscriptionCustomerCenterRestoreStarted)
    }
}
