@MainActor
protocol SubscriptionPurchaseContextProtocol: AnyObject {
    func check() async throws -> SubscriptionPurchaseOutcome

    func check(
        transaction: SubscriptionTransactionUpdate,
    ) -> SubscriptionPurchaseOutcome?

    /// Returns nil when a new purchase attempt should be started.
    func resume() async throws -> SubscriptionPurchaseOutcome?
}
