import Combine
import Router

@MainActor
final class SubscriptionViewModel: DModuleViewModel {
    private let arguments: SubscriptionArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SubscriptionArguments?,
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
                type: subscriptionStatus?.type,
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
