import DoglyadDatabase
import DoglyadNetwork
import Foundation

@MainActor
final class SubscriptionBackendRepository: SubscriptionBackendRepositoryProtocol {
    private let httpClient: DHttpClientProtocol
    private let securityDatabase: DSecurityDatabaseProtocol

    init(
        httpClient: DHttpClientProtocol,
        securityDatabase: DSecurityDatabaseProtocol,
    ) {
        self.httpClient = httpClient
        self.securityDatabase = securityDatabase
    }

    func configureIdentity() async throws {
        guard try await securityDatabase.fetchBillingIdentity() == nil else {
            return
        }
        let identity: BillingIdentityResponse = try await httpClient.post(
            endPoint: "/subscriptions/register",
        )
        try await saveIdentity(
            identity,
        )
    }

    func fetchOwnerID() async throws -> UUID {
        guard let identity = try await securityDatabase.fetchBillingIdentity() else {
            throw SubscriptionError.offeringsUnavailable
        }
        return identity.ownerId
    }

    func fetchPlans() async throws -> BillingProductsResponse {
        try await httpClient.get(
            endPoint: "/subscriptions/plans",
        )
    }

    func fetchStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        let response: BillingStatusResponse? = try await httpClient.get(
            endPoint: "/subscriptions/status",
        )
        guard let response else {
            return nil
        }
        guard let entitlement = configEntitlements[
            response.type,
        ] else {
            throw SubscriptionError.offeringsUnavailable
        }
        return SubscriptionStatus(
            planId: response.planId,
            type: response.type,
            entitlement: entitlement,
            availableCountPerDay: response.availableCountPerDay,
            source: response.source,
            expiresAt: response.expiresAt,
            isAutoRenewing: response.isAutoRenewing,
        )
    }

    func synchronizeAppleTransaction(
        signedTransaction: String,
    ) async throws -> Bool {
        let identity: BillingIdentityResponse? = try await httpClient.post(
            endPoint: "/subscriptions/sync_apple",
            body: BillingAppleRequest(
                signedTransaction: signedTransaction,
            ),
        )
        guard let identity else {
            return false
        }
        let previous = try await securityDatabase.fetchBillingIdentity()
        try await saveIdentity(
            identity,
        )
        return previous?.ownerId != identity.ownerId
    }

    func cancelRenewal() async throws {
        try await httpClient.post(
            endPoint: "/subscriptions/cancel",
        )
    }

    func createRecoveryKey() async throws -> String {
        let response: BillingRecoveryResponse = try await httpClient.post(
            endPoint: "/subscriptions/recovery_key",
        )
        return response.recoveryKey
    }

    func recover(
        key: String,
    ) async throws {
        let identity: BillingIdentityResponse = try await httpClient.post(
            endPoint: "/subscriptions/recover",
            body: BillingRecoveryRequest(
                recoveryKey: key,
            ),
        )
        try await saveIdentity(
            identity,
        )
    }

    func preparePayment(
        planID: String,
    ) async throws -> BillingPreparePaymentResponse {
        try await httpClient.post(
            endPoint: "/subscriptions/prepare_payment",
            body: BillingPreparePaymentRequest(
                planId: planID,
            ),
        )
    }

    func tokenizePayment(
        request: BillingTokenizePaymentRequest,
    ) async throws -> BillingPaymentResponse {
        try await httpClient.post(
            endPoint: "/subscriptions/tokenize_payment",
            body: request,
        )
    }

    func checkPayment(
        id: UUID,
        isAbandoned: Bool,
    ) async throws -> BillingPaymentResponse {
        try await httpClient.post(
            endPoint: "/subscriptions/check_payment",
            body: BillingCheckPaymentRequest(
                paymentId: id,
                isAbandoned: isAbandoned,
            ),
        )
    }

    private func saveIdentity(
        _ identity: BillingIdentityResponse,
    ) async throws {
        try await securityDatabase.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: identity.ownerId,
                accessToken: identity.accessToken,
            ),
        )
    }
}
