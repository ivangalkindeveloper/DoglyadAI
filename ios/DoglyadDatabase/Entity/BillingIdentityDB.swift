import Foundation

public struct BillingIdentityDB: Codable, Sendable {
    public let ownerId: UUID
    public let accessToken: String
    public let recoveryKey: String?

    public init(
        ownerId: UUID,
        accessToken: String,
        recoveryKey: String? = nil,
    ) {
        self.ownerId = ownerId
        self.accessToken = accessToken
        self.recoveryKey = recoveryKey
    }
}
