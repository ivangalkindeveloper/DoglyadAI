import Foundation

struct BillingPaymentResponse: Decodable, Sendable {
    let id: UUID
    let planId: String
    let status: BillingPaymentState
    let confirmationUrl: URL?
    let paymentMethodType: String?
    let recoveryKey: String?

    init(
        id: UUID,
        planId: String,
        status: BillingPaymentState,
        confirmationUrl: URL?,
        paymentMethodType: String?,
        recoveryKey: String? = nil,
    ) {
        self.id = id
        self.planId = planId
        self.status = status
        self.confirmationUrl = confirmationUrl
        self.paymentMethodType = paymentMethodType
        self.recoveryKey = recoveryKey
    }
}
