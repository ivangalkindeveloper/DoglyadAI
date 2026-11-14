import Foundation

public protocol DSecurityDatabaseProtocol: Sendable {
    func fetchBillingIdentity() async throws -> BillingIdentityDB?

    func setBillingIdentity(
        value: BillingIdentityDB,
    ) async throws

    func removeBillingIdentity() async throws

    func setBillingRecoveryKey(
        ownerId: UUID,
        value: String,
    ) async throws
}
