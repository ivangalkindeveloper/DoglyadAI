import Foundation

struct BillingPreparePaymentResponse: Decodable, Sendable {
    let payment: BillingPaymentResponse
    let shopId: String
    let clientApplicationKey: String
    let shopName: String
    let description: String
    let termsVersion: String
    let price: BillingPrice
}
