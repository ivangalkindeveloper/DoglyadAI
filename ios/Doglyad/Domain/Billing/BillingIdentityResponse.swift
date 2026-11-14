import Foundation

struct BillingIdentityResponse: Codable {
    let ownerId: UUID
    let accessToken: String
    let recoveryKey: String?

    init(
        ownerId: UUID,
        accessToken: String,
        recoveryKey: String?,
    ) {
        self.ownerId = ownerId
        self.accessToken = accessToken
        self.recoveryKey = recoveryKey
    }
}
