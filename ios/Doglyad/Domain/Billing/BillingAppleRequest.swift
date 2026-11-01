import Foundation

struct BillingAppleRequest: Encodable, Sendable {
    let signedTransaction: String
}
