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
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            state: RequestLimitExceededState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
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

    func onTapBack() {
        analytics.buttonTapped(
            .requestLimitBack,
        )
        coordinator.dismissSheet()
    }
}
