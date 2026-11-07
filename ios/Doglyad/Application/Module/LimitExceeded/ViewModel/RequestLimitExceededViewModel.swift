import Combine
import Router

@MainActor
final class RequestLimitExceededViewModel: DModuleViewModel<any RequestLimitExceededStateProtocol> {
    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        super.init(
            state: RequestLimitExceededState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .bottomSheet(
                .requestLimitExceeded,
            ),
        )
    }

    func onTapUpgrade() {
        analytics.buttonTapped(
            .requestLimitUpgrade,
        )
        coordinator.showPaywall(
            isSheetDismissalRequired: true,
        )
    }
}
