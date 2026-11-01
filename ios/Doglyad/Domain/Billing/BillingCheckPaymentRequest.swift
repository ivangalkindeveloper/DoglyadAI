import Foundation

struct BillingCheckPaymentRequest: Encodable, Sendable {
    let paymentId: UUID
    let isAbandoned: Bool
}
