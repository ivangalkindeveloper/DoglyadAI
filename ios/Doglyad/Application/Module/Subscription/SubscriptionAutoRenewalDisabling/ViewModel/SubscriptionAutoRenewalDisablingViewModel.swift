import Combine
import DoglyadUI

@MainActor
final class SubscriptionAutoRenewalDisablingViewModel: DModuleViewModel<any SubscriptionAutoRenewalDisablingStateProtocol> {
    private let messager: DMessager
    private let arguments: SubscriptionAutoRenewalDisablingArguments?
    private let disableAutoRenewal: () async throws -> Void

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments: SubscriptionAutoRenewalDisablingArguments?,
        disableAutoRenewal: @escaping () async throws -> Void,
    ) {
        self.messager = messager
        self.arguments = arguments
        self.disableAutoRenewal = disableAutoRenewal
        super.init(
            state: SubscriptionAutoRenewalDisablingInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .subscriptionAutoRenewalDisabling,
            ),
        )
    }

    var isProcessing: Bool {
        switch state {
        case _ as SubscriptionAutoRenewalDisablingLoadingState: true
        default: false
        }
    }

    func onTapConfirm() {
        guard !isProcessing else {
            return
        }
        let loading = SubscriptionAutoRenewalDisablingLoadingState()
        emit(
            loading,
        )
        operationTask = Task {
            do {
                try Task.checkCancellation()
                try await self.disableAutoRenewal()
                guard !Task.isCancelled, self.state === loading else {
                    return
                }
                self.messager.show(
                    type: .success,
                    title: self.l10n[
                        .subscriptionAutoRenewalDisablingSuccessTitle,
                    ],
                    description: self.l10n[
                        .subscriptionAutoRenewalDisablingSuccessDescription,
                    ],
                )
                self.coordinator.dismissSheet()
                self.arguments?.onDisableSuccess?()
            } catch {
                guard !Task.isCancelled, self.state === loading else {
                    return
                }
                self.emit(
                    SubscriptionAutoRenewalDisablingInitialState(),
                )
                self.messager.showUnknownError(
                    l10n: self.l10n,
                )
            }
        }
    }
}
