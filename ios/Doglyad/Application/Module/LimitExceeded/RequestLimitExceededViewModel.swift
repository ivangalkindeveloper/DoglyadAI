import Combine
import Router

@MainActor
final class RequestLimitExceededViewModel: DModuleViewModel {
    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
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
