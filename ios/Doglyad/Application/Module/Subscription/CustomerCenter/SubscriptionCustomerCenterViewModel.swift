import Combine
import Foundation
import UIKit

@MainActor
final class SubscriptionCustomerCenterViewModel: DModuleViewModel {
    private let arguments: SubscriptionCustomerCenterArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SubscriptionCustomerCenterArguments?,
        onRefreshStatus: @escaping () async -> Void,
    ) {
        self.arguments = arguments
        self.onRefreshStatus = onRefreshStatus
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .subscriptionCustomerCenter,
            ),
        )
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorDescription: String?

    func onTapClose() { coordinator.dismissSheet() }

    func onTapManageSubscription() {
        perform { try await self.container.subscriptionRepository.manageSubscription() }
    }

    func onTapRestore() {
        analytics.buttonTapped(
            .subscriptionCustomerCenterRestoreStarted,
        )
        perform {
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
        perform { try await self.container.subscriptionRepository.requestRefund() }
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
        _ operation: @escaping () async throws -> Void,
    ) {
        guard !isLoading else { return }
        isLoading = true
        errorDescription = nil
        Task {
            defer { isLoading = false }
            do {
                try await operation()
                await onRefreshStatus()
            } catch { errorDescription = l10n.text(
                .errorUnknownDescription,
            ) }
        }
    }
}
