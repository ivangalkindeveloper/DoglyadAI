import Foundation

@MainActor
protocol SubscriptionRepositoryProtocol: AnyObject {
    func fetchCatalog() async throws -> SubscriptionCatalog

    /// Reports the provider reference before presenting the purchase interface.
    func purchase(
        plan: SubscriptionPlan,
        onPurchasePrepared: @escaping (SubscriptionPurchaseReference) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome

    /// Returns whether synchronizing purchases changed the anonymous backend owner.
    func restorePurchases() async throws -> Bool

    /// Returns whether synchronizing purchases changed the anonymous backend owner.
    func synchronizeCurrentEntitlements() async throws -> Bool

    /// Reports verified transactions after backend synchronization.
    func observeChanges(
        _ observer: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws

    func manageSubscription() async throws

    func requestRefund() async throws
}
