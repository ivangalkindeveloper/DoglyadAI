import Foundation

enum SubscriptionPurchaseOutcome: Sendable {
    case cancelled
    case pending
    case completed(SubscriptionStatus?)
}
