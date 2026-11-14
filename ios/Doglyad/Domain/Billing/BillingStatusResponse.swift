import Foundation

struct BillingStatusResponse: Decodable {
    let type: SubscriptionType
    let source: SubscriptionSource?
    let planId: String
    let expiresAt: Date?
    let isAutoRenewing: Bool
    let recoveryKey: String?
    let availableCountPerDay: Int

    init(
        type: SubscriptionType,
        source: SubscriptionSource?,
        planId: String,
        expiresAt: Date?,
        isAutoRenewing: Bool,
        recoveryKey: String?,
        availableCountPerDay: Int,
    ) {
        self.type = type
        self.source = source
        self.planId = planId
        self.expiresAt = expiresAt
        self.isAutoRenewing = isAutoRenewing
        self.recoveryKey = recoveryKey
        self.availableCountPerDay = availableCountPerDay
    }
}
