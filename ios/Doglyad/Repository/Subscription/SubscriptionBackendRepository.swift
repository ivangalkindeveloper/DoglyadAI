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
        let ownerId = try await fetchOwnerID()
        let response: BillingStatusResponse? = try await httpClient.get(
            endPoint: "/subscriptions/status",
        )
        try await saveRecoveryKey(
            response?.recoveryKey,
            ownerId: ownerId,
        )
        return try buildSubscriptionStatus(
            response,
            configEntitlements: configEntitlements,
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

    func setAutoRenewal(
        isAutoRenewing: Bool,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        let ownerId = try await fetchOwnerID()
        let response: BillingStatusResponse? = try await httpClient.post(
            endPoint: "/subscriptions/auto_renewal",
            body: BillingAutoRenewalRequest(
                isAutoRenewing: isAutoRenewing,
            ),
        )
        try await saveRecoveryKey(
            response?.recoveryKey,
            ownerId: ownerId,
        )
        return try buildSubscriptionStatus(
            response,
            configEntitlements: configEntitlements,
        )
    }

    func fetchRecoveryKey() async throws -> String {
        guard let identity = try await securityDatabase.fetchBillingIdentity() else {
            throw SubscriptionError.offeringsUnavailable
        }
        if let key = identity.recoveryKey {
            return key
        }

        let response: BillingRecoveryResponse = try await httpClient.post(
            endPoint: "/subscriptions/recovery_key",
        )
        try await securityDatabase.setBillingRecoveryKey(
            ownerId: identity.ownerId,
            value: response.recoveryKey,
        )
        return response.recoveryKey
    }

    func recover(
        key: String,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        let response: BillingRecoveredAccessResponse = try await httpClient.post(
            endPoint: "/subscriptions/recover",
            body: BillingRecoveryRequest(
                recoveryKey: key,
            ),
        )
        try await saveIdentity(
            response.identity,
        )
        return try buildSubscriptionStatus(
            response.subscription,
            configEntitlements: configEntitlements,
        )
    }

    func preparePayment(
        planID: String,
        price: BillingPrice,
        isAutoRenewing: Bool,
    ) async throws -> BillingPreparePaymentResponse {
        let ownerId = try await fetchOwnerID()
        let response: BillingPreparePaymentResponse = try await httpClient.post(
            endPoint: "/subscriptions/prepare_payment",
            body: BillingPreparePaymentRequest(
                planId: planID,
                price: price,
                isAutoRenewing: isAutoRenewing,
            ),
        )
        try await saveRecoveryKey(
            response.payment.recoveryKey,
            ownerId: ownerId,
        )
        return response
    }

    func checkPayment(
        id: UUID,
        isAbandoned: Bool,
    ) async throws -> BillingPaymentResponse {
        let ownerId = try await fetchOwnerID()
        let response: BillingPaymentResponse = try await httpClient.post(
            endPoint: "/subscriptions/check_payment",
            body: BillingCheckPaymentRequest(
                paymentId: id,
                isAbandoned: isAbandoned,
            ),
        )
        try await saveRecoveryKey(
            response.recoveryKey,
            ownerId: ownerId,
        )
        return response
    }

    private func saveIdentity(
        _ identity: BillingIdentityResponse,
    ) async throws {
        let previous = try await securityDatabase.fetchBillingIdentity()
        try await securityDatabase.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: identity.ownerId,
                accessToken: identity.accessToken,
                recoveryKey: identity.recoveryKey ?? (previous?.ownerId == identity.ownerId ? previous?.recoveryKey : nil),
            ),
        )
    }

    private func saveRecoveryKey(
        _ key: String?,
        ownerId: UUID,
    ) async throws {
        guard let key else {
            return
        }
        try await securityDatabase.setBillingRecoveryKey(
            ownerId: ownerId,
            value: key,
        )
    }

    private func buildSubscriptionStatus(
        _ response: BillingStatusResponse?,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) throws -> SubscriptionStatus? {
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
}
