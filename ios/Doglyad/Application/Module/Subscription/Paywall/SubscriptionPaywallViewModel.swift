import Combine
import Foundation
import Router

@MainActor
final class SubscriptionPaywallViewModel: DModuleViewModel {
    private let arguments: SubscriptionPaywallArguments?
    private let onRefreshStatus: () async -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SubscriptionPaywallArguments?,
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
            analyticsDestination: .screen(
                .subscriptionPaywall,
            ),
        )
    }

    @Published private(set) var plans: [SubscriptionPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorDescription: String?

    var isCloseButtonVisible: Bool { !router.path.isEmpty }

    var closeAction: (() -> Void)? { isCloseButtonVisible ? { self.onTapClose() } : nil }

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
        guard !isLoading else { return }
        analytics.buttonTapped(
            .subscriptionPaywallPurchaseStarted,
            parameters: AnalyticsParameters(
                [.productId: .string(
                    plan.productId,
                )],
            ),
        )
        isLoading = true
        errorDescription = nil
        Task {
            defer { isLoading = false }
            do {
                let outcome = try await container.subscriptionRepository.purchase(
                    plan: plan,
                    configEntitlements: container.applicationConfig.entitlements,
                )
                switch outcome {
                case .cancelled: break
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
                    coordinator.dismissPaywall()
                }
            } catch { errorDescription = l10n.text(
                .errorUnknownDescription,
            ) }
        }
    }

    func onTapRetry() { loadPlans() }

    func onTapRestore() {
        guard !isLoading else { return }
        analytics.buttonTapped(
            .subscriptionPaywallRestoreStarted,
        )
        isLoading = true
        errorDescription = nil
        Task {
            defer { isLoading = false }
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
                if isSubscriptionActive {
                    coordinator.dismissPaywall()
                }
            } catch { errorDescription = l10n.text(
                .errorUnknownDescription,
            ) }
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
        guard !isLoading else { return }
        isLoading = true
        errorDescription = nil
        Task {
            defer { isLoading = false }
            do {
                plans = try await container.subscriptionRepository.fetchPlans()
                if plans.isEmpty { errorDescription = l10n.text(
                    .subscriptionOfferingsUnavailableDescription,
                ) }
            } catch { errorDescription = l10n.text(
                .subscriptionOfferingsUnavailableDescription,
            ) }
        }
    }
}
