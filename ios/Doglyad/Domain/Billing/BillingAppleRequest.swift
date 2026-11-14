import Foundation

struct BillingAppleRequest: Encodable, Sendable {
    let signedTransaction: String

    init(
        signedTransaction: String,
    ) {
        self.signedTransaction = signedTransaction
    }
}
