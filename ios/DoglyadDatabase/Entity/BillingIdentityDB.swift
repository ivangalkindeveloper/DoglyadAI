import Foundation

public struct BillingIdentityDB: Codable, Sendable {
    public let ownerId: UUID
    public let accessToken: String

    public init(
        ownerId: UUID,
        accessToken: String,
    ) {
        self.ownerId = ownerId
        self.accessToken = accessToken
    }
}
