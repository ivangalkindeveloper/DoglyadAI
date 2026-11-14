import Foundation

struct SubscriptionTransactionUpdate: Sendable {
    let transactionId: UInt64
    let planId: String
    let purchaseDate: Date
    let isActive: Bool
    let isOwnerChanged: Bool

    init(
        transactionId: UInt64,
        planId: String,
        purchaseDate: Date,
        isActive: Bool,
        isOwnerChanged: Bool,
    ) {
        self.transactionId = transactionId
        self.planId = planId
        self.purchaseDate = purchaseDate
        self.isActive = isActive
        self.isOwnerChanged = isOwnerChanged
    }
}
