import Foundation

struct BillingPreparePaymentResponse: Decodable, Sendable {
    let payment: BillingPaymentResponse
    let checkoutUrl: String?

    init(
        payment: BillingPaymentResponse,
        checkoutUrl: String?,
    ) {
        self.payment = payment
        self.checkoutUrl = checkoutUrl
    }
}
