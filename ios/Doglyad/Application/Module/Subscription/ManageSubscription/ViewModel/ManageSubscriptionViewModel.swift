import Combine
import DoglyadUI
import Foundation
import SwiftUI
import UIKit

@MainActor
final class ManageSubscriptionViewModel: DModuleViewModel<any ManageSubscriptionStateProtocol> {
    private let fetchProducts: () async throws -> BillingProductsResponse
    private let manageSubscription: () async throws -> Void
    private let restorePurchases: () async throws -> SubscriptionStatus?
    private let requestRefund: () async throws -> Void
    private var isDismissalRequested = false

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments _: ManageSubscriptionArguments?,
        manageSubscription: @escaping () async throws -> Void,
        restorePurchases: @escaping () async throws -> SubscriptionStatus?,
        requestRefund: @escaping () async throws -> Void,
        fetchProducts: (() async throws -> BillingProductsResponse)? = nil,
    ) {
        self.fetchProducts = fetchProducts ?? {
            try await container.subscriptionBackendRepository.fetchPlans()
        }
        self.manageSubscription = manageSubscription
        self.restorePurchases = restorePurchases
        self.requestRefund = requestRefund
        super.init(
            state: ManageSubscriptionLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .screen(
                .manageSubscription,
            ),
        )
    }

    var isProcessing: Bool {
        switch state {
        case _ as ManageSubscriptionLoadingState: true
        default: false
        }
    }

    var manageTitle: LocalizedStringResource {
        switch subscriptionStatus?.source {
        case .yookassa:
            l10n[
                .manageSubscriptionCancelRenewalButton,
            ]
        case .apple, .none:
            l10n[
                .manageSubscriptionManageButton,
            ]
        }
    }

    var manageDescription: LocalizedStringResource {
        switch subscriptionStatus?.source {
        case .yookassa:
            l10n[
                .manageSubscriptionCancelRenewalDescription,
            ]
        case .apple, .none:
            l10n[
                .manageSubscriptionAppleManageDescription,
            ]
        }
    }

    var isManageAvailable: Bool {
        switch subscriptionStatus?.source {
        case .yookassa: subscriptionStatus?.isAutoRenewing == true
        case .apple: true
        case .none: false
        }
    }

    var refundDescription: LocalizedStringResource {
        switch subscriptionStatus?.source {
        case .apple:
            l10n[
                .manageSubscriptionAppleRefundDescription,
            ]
        case .yookassa, .none:
            l10n[
                .manageSubscriptionYooKassaRefundDescription,
            ]
        }
    }

    private var content: ManageSubscriptionContentState? {
        switch state {
        case let content as ManageSubscriptionContentState: content
        case let loading as ManageSubscriptionLoadingState: loading.previousState
        case let failed as ManageSubscriptionFailedState: failed.previousState
        default: nil
        }
    }

    override func onInit() {
        load()
    }

    override func onSubscriptionChanged(
        _ status: SubscriptionStatus?,
    ) {
        switch state {
        case let content as ManageSubscriptionContentState:
            showContent(
                catalog: content.catalog,
                status: status,
            )
        case let failed as ManageSubscriptionFailedState:
            guard let previous = failed.previousState else {
                return
            }
            emit(
                ManageSubscriptionFailedState(
                    previousState: resolvedContent(
                        catalog: previous.catalog,
                        status: status,
                    ) ?? previous,
                    errorDescription: failed.errorDescription,
                ),
            )
        default: break
        }
    }

    override func onDisappear() {
        super.onDisappear()
        switch state {
        case let loading as ManageSubscriptionLoadingState:
            guard let previous = loading.previousState else {
                return
            }
            showContent(
                catalog: previous.catalog,
                status: subscriptionStatus,
            )
        default: break
        }
    }

    func onTapBack() {
        guard !router.path.isEmpty else {
            return
        }
        isDismissalRequested = true
        cancelOperationTask()
        lastTask?.cancel()
        analytics.buttonTapped(
            .manageSubscriptionBack,
        )
        coordinator.pop()
    }

    func onTapChangeType() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        analytics.buttonTapped(
            .manageSubscriptionChangeType,
            parameters: .subscription(
                type: subscriptionStatus?.type,
            ),
        )
        coordinator.screen(
            .paywall,
        )
    }

    func onTapRestore() {
        analytics.buttonTapped(
            .manageSubscriptionRestoreStarted,
        )
        perform {
            let status = try await self.restorePurchases()
            guard !Task.isCancelled else {
                return
            }
            self.updateSubscriptionStatus(
                status,
            )
            self.analytics.actionCompleted(
                .manageSubscriptionRestoreCompleted,
            )
        } noSubscriptionNotice: {
            self.l10n.text(
                .manageSubscriptionNoPurchasesDescription,
            )
        }
    }

    func onTapManageSubscription() {
        guard isManageAvailable else {
            return
        }
        perform {
            try await self.manageSubscription()
        }
    }

    func onTapRecovery() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        coordinator.screen(
            .subscriptionRecovery,
        )
    }

    func onTapSupport() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        UIApplication.openMail(
            subject: l10n.text(
                .manageSubscriptionTitle,
            ),
            body: "",
            recipient: container.applicationConfig.contactEmail,
        )
    }

    func onTapRefund() {
        switch subscriptionStatus?.source {
        case .yookassa, .none: onTapSupport()
        case .apple:
            perform {
                try await self.requestRefund()
            }
        }
    }

    func onTapRetry() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        load()
    }

    func onRefresh() {
        guard !isProcessing, content != nil, !isDismissalRequested else {
            return
        }
        perform {
            await self.refreshStatus()
        }
    }

    func summaryTextColor(
        _ type: SubscriptionType,
        theme: DTheme,
    ) -> Color {
        switch type {
        case .base: theme.color.grayscaleHeader
        case .pro: .white
        }
    }

    func summarySecondaryTextColor(
        _ type: SubscriptionType,
        theme: DTheme,
    ) -> Color {
        switch type {
        case .base: theme.color.grayscaleLabel
        case .pro: theme.color.grayscaleInput
        }
    }

    func summaryFeatureIconColor(
        _ type: SubscriptionType,
        theme: DTheme,
    ) -> Color {
        switch type {
        case .base: theme.color.successDefault
        case .pro: theme.color.successBackgroundStrong
        }
    }

    func summaryBackgroundGradient(
        _ type: SubscriptionType,
        theme: DTheme,
    ) -> LinearGradient? {
        switch type {
        case .base: nil
        case .pro: theme.color.gradientPrimary
        }
    }

    func summaryBackgroundOverlayColor(
        _ type: SubscriptionType,
        theme: DTheme,
    ) -> Color {
        switch type {
        case .base: .clear
        case .pro:
            theme.color.primaryDefaultStrong.opacity(
                0.6,
            )
        }
    }

    func summaryTitleShimmering(
        _ type: SubscriptionType,
    ) -> Bool {
        switch type {
        case .base: false
        case .pro: true
        }
    }

    func expirationDescription(
        _ status: SubscriptionStatus,
    ) -> String? {
        guard let date = status.expiresAt else {
            return nil
        }
        return l10n.text(
            .manageSubscriptionPaidUntilDescription,
            values: [.date: date.formatted(
                .dateTime.day().month(
                    .wide,
                ).year().locale(
                    l10n.locale,
                ),
            )],
        )
    }

    private func resolvedContent(
        catalog: BillingProductsResponse,
        status: SubscriptionStatus?,
        notice: String? = nil,
    ) -> ManageSubscriptionContentState? {
        guard let status else {
            return ManageSubscriptionInactiveState(
                catalog: catalog,
                notice: notice,
            )
        }
        guard let tier = catalog.tiers.first(
            where: {
                $0.id == status.type
            },
        ) else {
            return nil
        }
        return ManageSubscriptionActiveState(
            catalog: catalog,
            status: status,
            tier: tier,
        )
    }

    private func showContent(
        catalog: BillingProductsResponse,
        status: SubscriptionStatus?,
        notice: String? = nil,
    ) {
        guard let next = resolvedContent(
            catalog: catalog,
            status: status,
            notice: notice,
        ) else {
            emit(
                ManageSubscriptionFailedState(
                    previousState: content,
                    errorDescription: l10n.text(
                        .manageSubscriptionLoadFailedDescription,
                    ),
                ),
            )
            return
        }
        emit(
            next,
        )
    }

    private func load() {
        lastTask?.cancel()
        emit(
            ManageSubscriptionLoadingState(
                previousState: content,
            ),
        )
        let loading = state
        handle {
            await self.refreshStatus()
            return try await self.fetchProducts()
        } onMainSuccess: { catalog in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            self.showContent(
                catalog: catalog,
                status: self.subscriptionStatus,
            )
        } onMainApiError: { _ in
            self.failLoading(
                loading,
            )
        }
        onMainConnectionError: { _ in
            self.failLoading(
                loading,
            )
        }
        onMainUnknownError: { _ in
            self.failLoading(
                loading,
            )
        }
    }

    private func failLoading(
        _ loading: any ManageSubscriptionStateProtocol,
    ) {
        guard !Task.isCancelled, !isDismissalRequested, state === loading else {
            return
        }
        emit(
            ManageSubscriptionFailedState(
                previousState: content,
                errorDescription: l10n.text(
                    .manageSubscriptionLoadFailedDescription,
                ),
            ),
        )
    }

    private func perform(
        _ operation: @escaping () async throws -> Void,
        noSubscriptionNotice: (() -> String)? = nil,
    ) {
        guard !isProcessing, !isDismissalRequested, let previous = content else {
            return
        }
        let loading = ManageSubscriptionLoadingState(
            previousState: previous,
        )
        emit(
            loading,
        )
        operationTask = Task {
            guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                return
            }
            do {
                try await operation()
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                showContent(
                    catalog: previous.catalog,
                    status: subscriptionStatus,
                    notice: noSubscriptionNotice?(),
                )
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                emit(
                    ManageSubscriptionFailedState(
                        previousState: resolvedContent(
                            catalog: previous.catalog,
                            status: subscriptionStatus,
                        ) ?? previous,
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
            }
        }
    }
}
