import Foundation

@MainActor
protocol SubscriptionRepositoryProtocol: AnyObject {
    func configure()

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
