import Combine

@MainActor
final class SubscriptionChangeViewModel: DModuleViewModel<any SubscriptionChangeStateProtocol> {
    private let arguments: SubscriptionChangeArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: SubscriptionChangeArguments,
    ) {
        self.arguments = arguments
        super.init(
            state: SubscriptionChangeDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .subscriptionChange,
            ),
        )
    }

    var descriptionKey: L10NKey {
        switch arguments.source {
        case .apple: .subscriptionChangeAppleDescription
        case .robokassa, .none: .subscriptionChangeDescription
        }
    }

    func onTapConfirm() {
        coordinator.dismissSheet()
        coordinator.screen(
            .paywall,
        )
    }
}
