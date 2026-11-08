#if DEBUG
    import Combine
    import Foundation
    import Router

    @MainActor
    enum ManageSubscriptionPreviewFactory {
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
            for scenario: ManageSubscriptionPreviewScenario,
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
            case .applePro, .refunding:
                makeStatus(
                    source: .apple,
                )
            case .yooKassaBase:
                makeStatus(
                    source: .yookassa,
                    type: .base,
                )
            case .yooKassaPro, .updating, .operationFailed, .restoring, .managing:
                makeStatus(
                    source: .yookassa,
                )
            case .renewalOff:
                makeStatus(
                    source: .yookassa,
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
            fetchProducts: (() async throws -> BillingProductsResponse)? = nil,
        ) -> ManageSubscriptionViewModel {
            let statuses = CurrentValueSubject<SubscriptionStatus?, Never>(
                status,
            )
            return ManageSubscriptionViewModel(
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
                manageSubscription: {
                    if let manageOperation {
                        try await manageOperation()
                        return
                    }
                    guard var status = statuses.value else {
                        return
                    }
                    switch status.source {
                    case .yookassa:
                        status.isAutoRenewing = false
                        statuses.send(
                            status,
                        )
                    case .apple, .none: break
                    }
                },
                restorePurchases: {
                    statuses.value
                },
                requestRefund: {},
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
            )
        }

        static func apply(
            _ scenario: ManageSubscriptionPreviewScenario,
            to model: ManageSubscriptionViewModel,
        ) async {
            // Canvas may schedule its task before the screen's onAppear handler.
            while model.lastTask == nil {
                guard !Task.isCancelled else {
                    return
                }
                await Task.yield()
            }
            await model.lastTask?.value
            guard let content = model.state as? ManageSubscriptionSuccessState else {
                return
            }
            switch scenario {
            case .loading:
                model.emit(
                    ManageSubscriptionCatalogLoadingState(),
                    animation: nil,
                )
            case .updating:
                model.emit(
                    ManageSubscriptionRefreshLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .restoring:
                model.emit(
                    ManageSubscriptionRestoreLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .managing:
                model.emit(
                    ManageSubscriptionManagementLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .refunding:
                model.emit(
                    ManageSubscriptionRefundLoadingState(
                        previousState: content,
                    ),
                    animation: nil,
                )
            case .failed:
                model.emit(
                    ManageSubscriptionFailedState(
                        errorDescription: model.l10n.text(
                            .manageSubscriptionLoadFailedDescription,
                        ),
                    ),
                    animation: nil,
                )
            case .operationFailed:
                model.emit(
                    ManageSubscriptionFailedState(
                        previousState: content,
                        errorDescription: model.l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                    animation: nil,
                )
            case .appleBase, .applePro, .appleRenewalOff, .yooKassaBase, .yooKassaPro, .renewalOff, .inactive: break
            }
        }
    }
#endif
