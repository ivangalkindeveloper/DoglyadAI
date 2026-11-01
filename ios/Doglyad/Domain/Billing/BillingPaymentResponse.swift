import Foundation

struct BillingPaymentResponse: Decodable, Sendable {
    let id: UUID
    let planId: String
    let status: BillingPaymentState
    let confirmationUrl: URL?
    let paymentMethodType: String?
}
