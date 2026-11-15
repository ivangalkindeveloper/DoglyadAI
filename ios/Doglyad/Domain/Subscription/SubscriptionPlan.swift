import Foundation

struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let source: SubscriptionSource
    let type: SubscriptionType
    let period: SubscriptionPeriod
    let title: String
    let price: String
    let oldPrice: String?
    let billingPrice: BillingPrice?

    init(
        id: String,
        source: SubscriptionSource,
        type: SubscriptionType,
        period: SubscriptionPeriod,
        title: String,
        price: String,
        oldPrice: String? = nil,
        billingPrice: BillingPrice? = nil,
    ) {
        self.id = id
        self.source = source
        self.type = type
        self.period = period
        self.title = title
        self.price = price
        self.oldPrice = oldPrice
        self.billingPrice = billingPrice
    }
}
