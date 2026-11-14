import Foundation

struct BillingRecoveryResponse: Decodable {
    let recoveryKey: String

    init(
        recoveryKey: String,
    ) {
        self.recoveryKey = recoveryKey
    }
}
