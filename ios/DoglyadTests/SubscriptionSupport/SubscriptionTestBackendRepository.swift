@testable import Doglyad
import Foundation

@MainActor
final class SubscriptionTestBackendRepository: SubscriptionBackendRepositoryProtocol {
    var isAccessAvailable = false
    var status = SubscriptionStatus(
        planId: "monthly",
        type: .pro,
        entitlement: SubscriptionEntitlement(
            requestCountPerDay: 20,
            formCompletionViaMicrophone: .available,
            sendingReportByEmail: .available,
            settingsAI: .available,
        ),
        availableCountPerDay: 20,
        source: .apple,
    )
    var payments: [UUID: BillingPaymentResponse] = [:]
    var onCheckPayment: (() async throws -> Void)?
    private(set) var checkedPayments: [UUID] = []
    private(set) var statusRequestCount = 0
    private(set) var isRenewalCanceled = false

    init() {}

    func configureIdentity() async throws {}

    func fetchOwnerID() async throws -> UUID {
        UUID()
    }

    func fetchPlans() async throws -> BillingProductsResponse {
        BillingProductsResponse(
            products: [],
            tiers: [],
        )
    }

    func fetchStatus(
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        statusRequestCount += 1
        return isAccessAvailable ? status : nil
    }

    func synchronizeAppleTransaction(
        signedTransaction _: String,
    ) async throws -> Bool {
        false
    }

    func setAutoRenewal(
        isAutoRenewing: Bool,
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        isRenewalCanceled = !isAutoRenewing
        status.isAutoRenewing = isAutoRenewing
        return isAccessAvailable ? status : nil
    }

    func fetchRecoveryKey() async throws -> String {
        "test-recovery-key"
    }

    func recover(
        key _: String,
        configEntitlements _: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        isAccessAvailable = true
        return status
    }

    func preparePayment(
        planID _: String,
        price _: BillingPrice,
        isAutoRenewing _: Bool,
    ) async throws -> BillingPreparePaymentResponse {
        throw SubscriptionError.offeringsUnavailable
    }

    func checkPayment(
        id: UUID,
        isAbandoned _: Bool,
    ) async throws -> BillingPaymentResponse {
        checkedPayments.append(
            id,
        )
        try await onCheckPayment?()
        guard let payment = payments[
            id,
        ] else {
            throw SubscriptionError.offeringsUnavailable
        }
        return payment
    }
}
