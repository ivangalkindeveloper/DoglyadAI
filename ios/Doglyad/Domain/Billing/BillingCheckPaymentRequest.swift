import Foundation

struct BillingCheckPaymentRequest: Encodable, Sendable {
    let paymentId: UUID
    let isAbandoned: Bool

    init(
        paymentId: UUID,
        isAbandoned: Bool,
    ) {
        self.paymentId = paymentId
        self.isAbandoned = isAbandoned
    }
}
