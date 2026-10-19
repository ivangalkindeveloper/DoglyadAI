import Combine
import Foundation
import UIKit

@MainActor
final class SubscriptionCustomerCenterViewModel: DModuleViewModel<any SubscriptionCustomerCenterStateProtocol> {
    private let arguments: SubscriptionCustomerCenterArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SubscriptionCustomerCenterArguments?,
        onRefreshStatus: @escaping () async -> Void,
    ) {
        self.arguments = arguments
        self.onRefreshStatus = onRefreshStatus
        super.init(
            state: SubscriptionCustomerCenterReadyState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .subscriptionCustomerCenter,
            ),
        )
    }

    func onTapClose() { coordinator.dismissSheet() }

    func onTapManageSubscription() {
        perform(
            state: SubscriptionCustomerCenterLoadingState(),
        ) { try await self.container.subscriptionRepository.manageSubscription() }
    }

    func onTapRestore() {
        analytics.buttonTapped(
            .subscriptionCustomerCenterRestoreStarted,
        )
        perform(
            state: SubscriptionCustomerCenterLoadingState(),
        ) {
            let status = try await self.container.subscriptionRepository.restorePurchases(
                configEntitlements: self.container.applicationConfig.entitlements,
            )
            self.updateSubscriptionStatus(
                status,
            )
            self.analytics.actionCompleted(
                .subscriptionCustomerCenterRestoreCompleted,
            )
        }
    }

    func onTapRefund() {
        perform(
            state: SubscriptionCustomerCenterLoadingState(),
        ) { try await self.container.subscriptionRepository.requestRefund() }
    }

    func onTapSupport() {
        UIApplication.openMail(
            subject: l10n.text(
                .subscriptionSupportCenterTitle,
            ),
            body: "",
            recipient: container.applicationConfig.contactEmail,
        )
    }

    private func perform(
        state operationState: any SubscriptionCustomerCenterStateProtocol,
        _ operation: @escaping () async throws -> Void,
    ) {
        switch state {
        case _ as SubscriptionCustomerCenterLoadingState: return
        default: break
        }

        emit(
            operationState,
        )
        Task {
            do {
                try await operation()
                await onRefreshStatus()
                emit(
                    SubscriptionCustomerCenterReadyState(),
                )
            } catch {
                emit(
                    SubscriptionCustomerCenterFailedState(
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
            }
        }
    }
}
