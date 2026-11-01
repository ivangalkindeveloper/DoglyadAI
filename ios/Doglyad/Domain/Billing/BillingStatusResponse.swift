import Foundation

struct BillingStatusResponse: Decodable {
    let type: SubscriptionType
    let source: SubscriptionSource?
    let planId: String
    let expiresAt: Date?
    let isAutoRenewing: Bool
    let availableCountPerDay: Int
}
