import Combine
import DoglyadUI
import Foundation
import SwiftUI
import UIKit

@MainActor
final class SubscriptionManageViewModel: DModuleViewModel<any SubscriptionManageStateProtocol> {
    private let messager: DMessager
    private let fetchSubscriptionStatus: () async throws -> SubscriptionStatus?
    private let fetchProducts: () async throws -> BillingProductsResponse
    private let manageSubscription: () async throws -> Void
    private let restorePurchases: () async throws -> SubscriptionRestoreStrategy
    private let requestRefund: () async throws -> Void
    private var isDismissalRequested = false

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments _: SubscriptionManageArguments?,
        fetchSubscriptionStatus: (() async throws -> SubscriptionStatus?)? = nil,
        fetchProducts: (() async throws -> BillingProductsResponse)? = nil,
        manageSubscription: @escaping () async throws -> Void,
        restorePurchases: @escaping () async throws -> SubscriptionRestoreStrategy,
        requestRefund: @escaping () async throws -> Void,
    ) {
        self.messager = messager
        self.fetchSubscriptionStatus = fetchSubscriptionStatus ?? {
            try await container.subscriptionBackendRepository.fetchStatus(
                configEntitlements: container.applicationConfig.entitlements,
            )
        }
        self.fetchProducts = fetchProducts ?? {
            try await container.subscriptionBackendRepository.fetchPlans()
        }
        self.manageSubscription = manageSubscription
        self.restorePurchases = restorePurchases
        self.requestRefund = requestRefund
        super.init(
            state: SubscriptionManageCatalogLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .subscriptionManage,
            ),
        )
    }

    var isProcessing: Bool {
        switch state {
        case _ as SubscriptionManageLoadingState: true
        default: false
        }
    }

    var manageTitle: LocalizedStringResource {
        l10n[
            .subscriptionManageManageButton,
        ]
    }
    var manageDescription: LocalizedStringResource {
        l10n[
            .subscriptionManageAppleManageDescription,
        ]
    }
    var isManageAvailable: Bool {
        subscriptionStatus?.source == .apple
    }
    var isChangePlanAvailable: Bool {
        !isProcessing
    }

    var refundDescription: LocalizedStringResource {
        switch subscriptionStatus?.source {
        case .apple:
            l10n[
                .subscriptionManageAppleRefundDescription,
            ]
        case .robokassa, .none:
            l10n[
                .subscriptionManageRobokassaRefundDescription,
            ]
        }
    }

    private var content: SubscriptionManageSuccessState? {
        switch state {
        case let content as SubscriptionManageSuccessState: content
        case let loading as SubscriptionManageLoadingState: loading.previousState
        case let failed as SubscriptionManageErrorState: failed.previousState
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
        case let content as SubscriptionManageSuccessState:
            showContent(
                catalog: content.catalog,
                status: status,
            )
        case let failed as SubscriptionManageErrorState:
            guard let previous = failed.previousState else {
                return
            }
            emit(
                SubscriptionManageErrorState(
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
        case let loading as SubscriptionManageLoadingState:
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
            .subscriptionManageBack,
        )
        coordinator.pop()
    }

    func onTapChangeType() {
        guard isChangePlanAvailable, !isDismissalRequested else {
            return
        }
        analytics.buttonTapped(
            .subscriptionManageChangeType,
            parameters: .subscription(
                type: subscriptionStatus?.type,
            ),
        )
        guard subscriptionStatus != nil else {
            coordinator.screen(
                .paywall,
            )
            return
        }
        coordinator.sheet(
            .subscriptionChange,
            arguments: SubscriptionChangeArguments(
                source: subscriptionStatus?.source,
            ),
        )
    }

    func onTapRestore() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        restoreAccess()
    }

    func onTapSubscriptionManage() {
        guard isManageAvailable else {
            return
        }
        perform(
            loadingType: SubscriptionManageManagementLoadingState.self,
        ) {
            try await self.manageSubscription()
        }
    }

    func onTapDisableAutoRenewal() {
        guard !isProcessing, !isDismissalRequested, let status = subscriptionStatus,
              status.source == .robokassa, status.isAutoRenewing
        else {
            return
        }
        coordinator.sheet(
            .subscriptionAutoRenewalDisabling,
            arguments: SubscriptionAutoRenewalDisablingArguments(
                onDisableSuccess: { [weak self] in
                    self?.onRefresh()
                },
            ),
        )
    }

    func onTapCopyRecoveryKey() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        performLocalOperation {
            try await self.container.subscriptionBackendRepository.fetchRecoveryKey()
        } onSuccess: { key in
            guard !self.isDismissalRequested else {
                return
            }
            UIPasteboard.general.string = key
            self.messager.show(
                type: .success,
                title: self.l10n[
                    .subscriptionManageRecoveryCopiedDescription,
                ],
            )
        } onFailure: {
            _ in
            self.emit(
                SubscriptionManageErrorState(
                    previousState: self.content,
                    errorDescription: self.l10n.text(
                        .errorUnknownDescription,
                    ),
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapSupport() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        UIApplication.openMail(
            subject: l10n.text(
                .subscriptionManageTitle,
            ),
            body: "",
            recipient: container.applicationConfig.contactEmail,
        )
    }

    func onTapRefund() {
        switch subscriptionStatus?.source {
        case .robokassa, .none: onTapSupport()
        case .apple:
            perform(
                loadingType: SubscriptionManageRefundLoadingState.self,
            ) {
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
        perform(
            loadingType: SubscriptionManageRefreshLoadingState.self,
        ) {
            let status = try await self.fetchSubscriptionStatus()
            self.updateSubscriptionStatus(
                status,
            )
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
        case .pro: theme.color.gradientPrimaryWeak
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
            .subscriptionManagePaidUntilDescription,
            values: [.date: date.formatted(
                .dateTime.day().month(
                    .wide,
                ).year().locale(
                    l10n.locale,
                ),
            )],
        )
    }

    private func restoreAccess() {
        cancelOperationTask()
        analytics.buttonTapped(
            .subscriptionManageRestoreStarted,
        )
        var notice: String?
        perform(
            loadingType: SubscriptionManageRestoreLoadingState.self,
        ) {
            let strategy = try await self.restorePurchases()
            guard !Task.isCancelled else {
                return
            }
            switch strategy {
            case .completed:
                if self.subscriptionStatus == nil {
                    notice = self.l10n.text(
                        .subscriptionManageNoPurchasesDescription,
                    )
                }
                self.analytics.actionCompleted(
                    .subscriptionManageRestoreCompleted,
                )
            case .recoveryKeyRequired:
                self.coordinator.screen(
                    .subscriptionRecovery,
                )
            }
        } noSubscriptionNotice: {
            notice
        }
    }

    private func resolvedContent(
        catalog: BillingProductsResponse,
        status: SubscriptionStatus?,
        notice: String? = nil,
    ) -> SubscriptionManageSuccessState? {
        guard let status else {
            return SubscriptionManageInactiveState(
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
        return SubscriptionManageActiveState(
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
                SubscriptionManageErrorState(
                    previousState: content,
                    errorDescription: l10n.text(
                        .errorUnknownDescription,
                    ),
                ),
            )
            messager.showUnknownError(
                l10n: l10n,
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
            SubscriptionManageCatalogLoadingState(
                previousState: content,
            ),
        )
        let loading = state
        handle {
            let status = try await self.fetchSubscriptionStatus()
            let catalog = try await self.fetchProducts()
            return (status, catalog)
        } onMainSuccess: { status, catalog in
            guard !Task.isCancelled, !self.isDismissalRequested, self.state === loading else {
                return
            }
            self.updateSubscriptionStatus(
                status,
            )
            self.showContent(
                catalog: catalog,
                status: status,
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
        _ loading: any SubscriptionManageStateProtocol,
    ) {
        guard !Task.isCancelled, !isDismissalRequested, state === loading else {
            return
        }
        emit(
            SubscriptionManageErrorState(
                previousState: content,
                errorDescription: l10n.text(
                    .errorUnknownDescription,
                ),
            ),
        )
        messager.showUnknownError(
            l10n: l10n,
        )
    }

    private func perform(
        loadingType: SubscriptionManageLoadingState.Type,
        _ operation: @escaping () async throws -> Void,
        noSubscriptionNotice: (() -> String?)? = nil,
    ) {
        guard !isProcessing, !isDismissalRequested, let previous = content else {
            return
        }
        let loading = loadingType.init(
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
                    SubscriptionManageErrorState(
                        previousState: resolvedContent(
                            catalog: previous.catalog,
                            status: subscriptionStatus,
                        ) ?? previous,
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }
}
