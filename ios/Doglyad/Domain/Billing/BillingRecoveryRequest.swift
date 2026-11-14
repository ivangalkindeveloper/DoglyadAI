import Foundation

struct BillingRecoveryRequest: Encodable, Sendable {
    let recoveryKey: String

    init(
        recoveryKey: String,
    ) {
        self.recoveryKey = recoveryKey
    }
}
