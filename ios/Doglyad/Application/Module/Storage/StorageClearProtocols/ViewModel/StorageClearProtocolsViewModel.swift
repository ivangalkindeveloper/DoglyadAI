import Combine

@MainActor
final class StorageClearProtocolsViewModel: DModuleViewModel<any StorageClearProtocolsStateProtocol> {
    private let arguments: StorageClearProtocolsArguments?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: StorageClearProtocolsArguments?,
    ) {
        self.arguments = arguments
        super.init(
            state: StorageClearProtocolsDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .bottomSheet(
                .storageClearProtocols,
            ),
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(
            .storageClearProtocolsConfirm,
        )
        coordinator.dismissSheet()
        arguments?.onConfirm()
    }
}
