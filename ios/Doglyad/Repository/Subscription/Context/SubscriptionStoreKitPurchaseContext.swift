import Foundation

@MainActor
final class SubscriptionStoreKitPurchaseContext: SubscriptionPurchaseContextProtocol {
    private let planID: String
    private let previousTransactionID: UInt64?
    private let previousPurchaseDate: Date?

    init(
        planID: String,
        previousTransactionID: UInt64?,
        previousPurchaseDate: Date?,
    ) {
        self.planID = planID
        self.previousTransactionID = previousTransactionID
        self.previousPurchaseDate = previousPurchaseDate
    }

    func check() async throws -> SubscriptionPurchaseOutcome {
        .pending
    }

    func check(
        transaction: SubscriptionTransactionUpdate,
    ) -> SubscriptionPurchaseOutcome? {
        guard transaction.planId == planID, transaction.transactionId != previousTransactionID,
              previousPurchaseDate.map(
                  {
                      transaction.purchaseDate > $0
                  },
              ) ?? true
        else {
            return nil
        }
        return transaction.isActive ? .completed(
            nil,
        ) : .pending
    }

    func resume() async throws -> SubscriptionPurchaseOutcome? {
        nil
    }
}
