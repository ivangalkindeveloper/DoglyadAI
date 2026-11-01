import Foundation

struct BillingTokenizePaymentRequest: Encodable, Sendable {
    let paymentId: UUID
    let paymentToken: String
    let termsVersion: String
    let isAutoRenewalAccepted: Bool
}
