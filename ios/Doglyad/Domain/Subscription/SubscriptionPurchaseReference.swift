import Foundation

enum SubscriptionPurchaseReference: Sendable {
    case apple(previousTransactionId: UInt64?, previousPurchaseDate: Date?)
    case yookassa(paymentId: UUID)
}
