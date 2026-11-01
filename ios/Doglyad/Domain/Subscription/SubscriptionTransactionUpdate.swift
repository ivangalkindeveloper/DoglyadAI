import Foundation

struct SubscriptionTransactionUpdate: Sendable {
    let transactionId: UInt64
    let planId: String
    let purchaseDate: Date
    let isActive: Bool
    let isOwnerChanged: Bool
}
