import Combine

@MainActor
final class StorageClearSpeechModelViewModel: DModuleViewModel<any StorageClearSpeechModelStateProtocol> {
    private let arguments: StorageClearSpeechModelArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: StorageClearSpeechModelArguments,
    ) {
        self.arguments = arguments
        super.init(
            state: StorageClearSpeechModelDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .storageClearSpeechModel,
            ),
        )
    }

    func onTapConfirm() {
        analytics.buttonTapped(
            .storageClearSpeechModelConfirm,
        )
        coordinator.dismissSheet()
        arguments.onConfirm()
    }
}
