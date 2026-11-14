@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct BillingRecoveryTests {
    init() {}

    @Test
    func confirmedPaymentSavesRecoveryKeyAndCopyUsesTheCache() async throws {
        let ownerId = UUID()
        let paymentId = UUID()
        let key = String(
            repeating: "A",
            count: 48,
        )
        let store = DSecurityDatabase(
            service: "BillingRecoveryTests." + UUID().uuidString,
        )
        try await store.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: ownerId,
                accessToken: "owner-token",
            ),
        )
        let json = """
        {"id":"\(paymentId)","planId":"monthly","status":"succeeded","recoveryKey":"\(key)"}
        """
        let http = RobokassaTestHttpClient(
            responses: ["/subscriptions/check_payment": Data(
                json.utf8,
            )],
        )
        let repository = SubscriptionBackendRepository(
            httpClient: http,
            securityDatabase: store,
        )
        _ = try await repository.checkPayment(
            id: paymentId,
            isAbandoned: false,
        )
        #expect(
            try await repository.fetchRecoveryKey() == key,
        )
        #expect(
            try await repository.fetchRecoveryKey() == key,
        )
        #expect(
            await http.requests == ["/subscriptions/check_payment"],
        )
        #expect(
            try await store.fetchBillingIdentity()?.recoveryKey == key,
        )
        try await store.removeBillingIdentity()
    }

    @Test
    func recoveryLoadsTheSubscriptionInOneRequest() async throws {
        let ownerId = UUID()
        let key = String(
            repeating: "B",
            count: 48,
        )
        let store = DSecurityDatabase(
            service: "BillingRecoveryTests." + UUID().uuidString,
        )
        try await store.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: UUID(),
                accessToken: "new-phone-token",
            ),
        )
        let json = """
        {"identity":{"ownerId":"\(ownerId)","accessToken":"restored-token","recoveryKey":"\(key)"},"subscription":{"type":"pro","source":"robokassa","planId":"monthly","isAutoRenewing":true,"availableCountPerDay":20,"recoveryKey":"\(key)"}}
        """
        let http = RobokassaTestHttpClient(
            responses: ["/subscriptions/recover": Data(
                json.utf8,
            )],
        )
        let repository = SubscriptionBackendRepository(
            httpClient: http,
            securityDatabase: store,
        )
        let entitlements = SubscriptionManagePreviewFactory.makeContainer().applicationConfig.entitlements
        let status = try await repository.recover(
            key: key,
            configEntitlements: entitlements,
        )
        #expect(
            status?.planId == "monthly" && status?.isAutoRenewing == true,
        )
        #expect(
            await http.requests == ["/subscriptions/recover"],
        )
        #expect(
            try await store.fetchBillingIdentity()?.ownerId == ownerId,
        )
        #expect(
            try await repository.fetchRecoveryKey() == key,
        )
        try await store.removeBillingIdentity()
    }

    @Test
    func delayedKeyCannotOverwriteAnotherOwnersIdentity() async throws {
        let store = DSecurityDatabase(
            service: "BillingRecoveryTests." + UUID().uuidString,
        )
        let oldOwner = UUID()
        let newOwner = UUID()
        try await store.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: newOwner,
                accessToken: "new-token",
                recoveryKey: "new-key",
            ),
        )
        do {
            try await store.setBillingRecoveryKey(
                ownerId: oldOwner,
                value: "old-key",
            )
            Issue.record(
                "A late response must retain the current owner's key",
            )
        } catch is CancellationError {}
        let identity = try await store.fetchBillingIdentity()
        #expect(
            identity?.ownerId == newOwner && identity?.recoveryKey == "new-key",
        )
        try await store.removeBillingIdentity()
    }
}
