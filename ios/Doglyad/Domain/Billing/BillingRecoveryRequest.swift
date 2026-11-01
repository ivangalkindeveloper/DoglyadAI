import Foundation

struct BillingRecoveryRequest: Encodable, Sendable {
    let recoveryKey: String
}
