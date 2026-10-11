import Foundation

@MainActor
protocol SubscriptionRepositoryProtocol: AnyObject {
    func configure()

    func fetchPlans() async throws -> [SubscriptionPlan]

    func purchase(
        plan: SubscriptionPlan,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionPurchaseOutcome

    func manageSubscription() async throws

    func requestRefund() async throws

    func cachedStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func fetchStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func restorePurchases(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?

    func incrementRequestCount(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus?
}
