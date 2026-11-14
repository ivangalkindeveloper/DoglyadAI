import Foundation

@MainActor
protocol SubscriptionRepositoryProtocol: AnyObject {
    func fetchCatalog() async throws -> SubscriptionCatalog

    func purchase(
        plan: SubscriptionPlan,
        isAutoRenewing: Bool,
        onPurchasePrepared: @escaping (SubscriptionPurchaseContextProtocol) -> Void,
    ) async throws -> SubscriptionPurchaseOutcome

    func restorePurchases() async throws -> SubscriptionRestoreStrategy

    func synchronizeCurrentEntitlements() async throws -> Bool

    func observeChanges(
        _ observer: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
    ) async throws

    func manageSubscription() async throws

    func requestRefund() async throws
}
