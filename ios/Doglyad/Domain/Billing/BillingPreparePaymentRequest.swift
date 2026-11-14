import Foundation

struct BillingPreparePaymentRequest: Encodable, Sendable {
    let planId: String
    let price: BillingPrice
    let isAutoRenewing: Bool

    init(
        planId: String,
        price: BillingPrice,
        isAutoRenewing: Bool,
    ) {
        self.planId = planId
        self.price = price
        self.isAutoRenewing = isAutoRenewing
    }
}
