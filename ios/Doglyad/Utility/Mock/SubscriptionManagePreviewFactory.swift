#if DEBUG
    import Combine
    import DoglyadUI
    import Foundation
    import Router

    @MainActor
    enum SubscriptionManagePreviewFactory {
        static func makeContainer(
            code: String = "ru",
        ) -> DependencyContainer {
            DependencyContainer.makePreviewable(
                l10n: L10NPreviewFactory.make(
                    code: code,
                ),
            )
        }

        static func makeStatus(
            source: SubscriptionSource,
            type: SubscriptionType = .pro,
            isAutoRenewing: Bool = true,
        ) -> SubscriptionStatus {
            SubscriptionStatus(
                planId: "\(type.rawValue)_monthly",
                type: type,
                entitlement: DevelopmentPreviewFactory.make().application.entitlements[
                    type,
                ]!,
                availableCountPerDay: DevelopmentPreviewFactory.make().application.entitlements[
                    type,
                ]!.requestCountPerDay - 3,
                source: source,
                expiresAt: Date(
                    timeIntervalSince1970: 1796126400,
                ),
                isAutoRenewing: isAutoRenewing,
            )
        }

        static func status(
            for scenario: SubscriptionManagePreviewScenario,
        ) -> SubscriptionStatus? {
            switch scenario {
            case .appleBase:
                makeStatus(
                    source: .apple,
                    type: .base,
                )
            case .appleRenewalOff:
                makeStatus(
                    source: .apple,
                    isAutoRenewing: false,
                )
            case .applePro, .refunding, .restoring, .managing, .operationFailed:
                makeStatus(
                    source: .apple,
                )
            case .robokassaBase:
                makeStatus(
                    source: .robokassa,
                    type: .base,
                )
            case .robokassaPro, .updating, .recoveredAccess, .purchaseCompletedSuccess:
                makeStatus(
                    source: .robokassa,
                )
            case .renewalOff, .autoRenewalDisabledSuccess:
                makeStatus(
                    source: .robokassa,
                    isAutoRenewing: false,
                )
            case .inactive, .loading, .failed: nil
            }
        }

        static func makeViewModel(
            container: DependencyContainer,
            router: DRouter,
            status: SubscriptionStatus? = nil,
            isLoadingFailed: Bool = false,
            manageOperation: (() async throws -> Void)? = nil,
            fetchSubscriptionStatus: (() async throws -> SubscriptionStatus?)? = nil,
            fetchProducts: (() async throws -> BillingProductsResponse)? = nil,
        ) -> SubscriptionManageViewModel {
            let statuses = CurrentValueSubject<SubscriptionStatus?, Never>(
                status,
            )
            return SubscriptionManageViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    statuses.value
                },
                observeSubscriptionStatus: {
                    statuses.sink(
                        receiveValue: $0,
                    )
                },
                onSubscriptionStatusUpdated: {
                    statuses.send(
                        $0,
                    )
                },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: nil,
                fetchSubscriptionStatus: {
                    if let fetchSubscriptionStatus {
                        return try await fetchSubscriptionStatus()
                    }
                    return statuses.value
                },
                fetchProducts: {
                    if let fetchProducts {
                        return try await fetchProducts()
                    }
                    if isLoadingFailed {
                        throw URLError(
                            .notConnectedToInternet,
                        )
                    }
                    return try await SubscriptionPreviewRepository(
                        locale: container.l10n.locale,
                    ).fetchProducts()
                },
                manageSubscription: {
                    if let manageOperation {
                        try await manageOperation()
                        return
                    }
                    guard var status = statuses.value else {
                        return
                    }
                    switch status.source {
                    case .robokassa:
                        status.isAutoRenewing = false
                        statuses.send(
                            status,
                        )
                    case .apple, .none: break
                    }
                },
                restorePurchases: {
                    guard let status = statuses.value else {
                        return .completed(
                            isOwnerChanged: false,
                        )
                    }
                    switch status.source {
                    case .robokassa:
                        return .recoveryKeyRequired
                    case .apple, .none:
                        return .completed(
                            isOwnerChanged: false,
                        )
                    }
                },
                requestRefund: {},
            )
        }

        static func apply(
            _ scenario: SubscriptionManagePreviewScenario,
            to model: SubscriptionManageViewModel,
        ) async {
            // Canvas may schedule its task before the screen's onAppear handler.
            while model.lastTask == nil {
                guard !Task.isCancelled else {
                    return
                }
                await Task.yield()
            }
            await model.lastTask?.value
            guard let content = model.state as? SubscriptionManageSuccessState else {
                return
            }
            switch scenario {
            case .loading:
                model.emit(
                    SubscriptionManageCatalogLoadingState(),
                    animation: nil,
                )
            case .updating:
                model.emit(
                    SubscriptionManageRefreshLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .restoring:
                model.emit(
                    SubscriptionManageRestoreLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .managing:
                model.emit(
                    SubscriptionManageManagementLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .refunding:
                model.emit(
                    SubscriptionManageRefundLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .failed:
                model.emit(
                    SubscriptionManageErrorState(
                        errorDescription: model.l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                    animation: nil,
                )
            case .operationFailed:
                model.emit(
                    SubscriptionManageErrorState(
                        previousState: content,
                        errorDescription: model.l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                    animation: nil,
                )
            case .autoRenewalDisabledSuccess, .recoveredAccess, .purchaseCompletedSuccess, .appleBase, .applePro, .appleRenewalOff, .robokassaBase, .robokassaPro, .renewalOff, .inactive: break
            }
        }
    }
#endif
