import Foundation

struct BillingPreparePaymentRequest: Encodable, Sendable {
    let planId: String
    let price: BillingPrice
    let isAutoRenewing: Bool
    let legalDate: Date

    init(
        planId: String,
        price: BillingPrice,
        isAutoRenewing: Bool,
        legalDate: Date,
    ) {
        self.planId = planId
        self.price = price
        self.isAutoRenewing = isAutoRenewing
        self.legalDate = legalDate
    }
}
