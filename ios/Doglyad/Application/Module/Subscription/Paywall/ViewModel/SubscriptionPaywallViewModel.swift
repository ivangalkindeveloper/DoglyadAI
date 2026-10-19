import Combine
import Foundation
import Router

@MainActor
final class SubscriptionPaywallViewModel: DModuleViewModel<any SubscriptionPaywallStateProtocol> {
    @Published private(set) var plans: [SubscriptionPlan] = []
    let isDismissible: Bool
    private let arguments: SubscriptionPaywallArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SubscriptionPaywallArguments?,
        onRefreshStatus: @escaping () async -> Void,
    ) {
        self.arguments = arguments
        self.onRefreshStatus = onRefreshStatus
        isDismissible = !router.path.isEmpty
        super.init(
            state: SubscriptionPaywallLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .subscriptionPaywall,
            ),
        )
    }

    override func onInit() { loadPlans() }

    func onTapClose() {
        analytics.buttonTapped(
            .subscriptionPaywallCancel,
        )
        coordinator.dismissPaywall()
    }

    func planTitle(
        _ plan: SubscriptionPlan,
    ) -> LocalizedStringResource {
        switch plan.kind {
        case .custom: l10n[
                .subscriptionPaywallPlanLabel,
            ]
        case .lifetime: l10n[
                .subscriptionPaywallLifetimeLabel,
            ]
        case .annual: l10n[
                .subscriptionPaywallAnnualLabel,
            ]
        case .sixMonth: l10n[
                .subscriptionPaywallSixMonthLabel,
            ]
        case .threeMonth: l10n[
                .subscriptionPaywallThreeMonthLabel,
            ]
        case .twoMonth: l10n[
                .subscriptionPaywallTwoMonthLabel,
            ]
        case .monthly: l10n[
                .subscriptionPaywallMonthlyLabel,
            ]
        case .weekly: l10n[
                .subscriptionPaywallWeeklyLabel,
            ]
        }
    }

    func planPrice(
        _ plan: SubscriptionPlan,
    ) -> LocalizedStringResource {
        l10n.resource(
            .subscriptionPaywallPriceDescription,
            values: ["price": plan.price],
        )
    }

    func onTapPlan(
        _ plan: SubscriptionPlan,
    ) {
        switch state {
        case _ as SubscriptionPaywallRestoringState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallLoadingState: return
        case _ as SubscriptionPaywallContentState, _ as SubscriptionPaywallFailedState:
            guard !plans.isEmpty else { return }
        default: return
        }
        analytics.buttonTapped(
            .subscriptionPaywallPurchaseStarted,
            parameters: AnalyticsParameters(
                [.productId: .string(
                    plan.productId,
                )],
            ),
        )
        emit(
            SubscriptionPaywallPurchasingState(
                plan: plan,
            ),
        )
        Task {
            do {
                let outcome = try await container.subscriptionRepository.purchase(
                    plan: plan,
                    configEntitlements: container.applicationConfig.entitlements,
                )
                switch outcome {
                case .cancelled:
                    emit(
                        SubscriptionPaywallContentState(),
                    )
                case let .completed(
                    status,
                ):
                    updateSubscriptionStatus(
                        status,
                    )
                    analytics.actionCompleted(
                        .subscriptionPurchaseCompleted,
                    )
                    await onRefreshStatus()
                    emit(
                        SubscriptionPaywallContentState(),
                    )
                    coordinator.dismissPaywall()
                }
            } catch {
                emit(
                    SubscriptionPaywallFailedState(
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
            }
        }
    }

    func onTapRetry() { loadPlans() }

    func onTapRestore() {
        switch state {
        case _ as SubscriptionPaywallRestoringState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallLoadingState: return
        default: break
        }
        analytics.buttonTapped(
            .subscriptionPaywallRestoreStarted,
        )
        let previous = state
        emit(
            SubscriptionPaywallRestoringState(
                previousState: previous,
            ),
        )
        Task {
            do {
                let status = try await container.subscriptionRepository.restorePurchases(
                    configEntitlements: container.applicationConfig.entitlements,
                )
                updateSubscriptionStatus(
                    status,
                )
                analytics.actionCompleted(
                    .subscriptionRestoreCompleted,
                )
                await onRefreshStatus()
                emit(
                    previous,
                )
                switch subscriptionStatus {
                case .some: coordinator.dismissPaywall()
                case .none: break
                }
            } catch {
                emit(
                    SubscriptionPaywallFailedState(
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
            }
        }
    }

    func onTapPrivacyPolicy() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: l10n[
                    .privacyPolicyTitle,
                ],
            ),
        )
    }

    func onTapTerms() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: l10n[
                    .termsAndConditionsTitle,
                ],
            ),
        )
    }

    private func loadPlans() {
        switch state {
        case _ as SubscriptionPaywallRestoringState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallLoadingState:
            // The initial loading state has no running request until onInit.
            guard lastTask == nil else { return }
        default: break
        }

        emit(
            SubscriptionPaywallLoadingState(),
        )
        handle {
            try await self.container.subscriptionRepository.fetchPlans()
        } onMainSuccess: { plans in
            guard !plans.isEmpty else {
                self.emit(
                    SubscriptionPaywallFailedState(
                        errorDescription: self.l10n.text(
                            .subscriptionOfferingsUnavailableDescription,
                        ),
                    ),
                )
                return
            }
            self.plans = plans
            self.emit(
                SubscriptionPaywallContentState(),
            )
        } onMainApiError: { _ in
            self.emit(
                SubscriptionPaywallFailedState(
                    errorDescription: self.l10n.text(
                        .subscriptionOfferingsUnavailableDescription,
                    ),
                ),
            )
        } onMainConnectionError: { _ in
            self.emit(
                SubscriptionPaywallFailedState(
                    errorDescription: self.l10n.text(
                        .subscriptionOfferingsUnavailableDescription,
                    ),
                ),
            )
        } onMainUnknownError: { _ in
            self.emit(
                SubscriptionPaywallFailedState(
                    errorDescription: self.l10n.text(
                        .subscriptionOfferingsUnavailableDescription,
                    ),
                ),
            )
        }
    }
}
