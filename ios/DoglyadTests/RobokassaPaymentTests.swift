@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct RobokassaPaymentTests {
    init() {}

    @Test
    func alreadyConfirmedPaymentIsRecoveredWithoutOpeningPaymentForm() async throws {
        let id = UUID().uuidString
        let prepare = """
        {"payment":{"id":"\(id)","planId":"monthly","status":"succeeded","confirmationUrl":"https://robokassa.ru/confirm","paymentMethodType":"bank_card"},
        "checkoutUrl":"https://auth.robokassa.ru/merchant/Invoice/test"}
        """
        let http = RobokassaTestHttpClient(
            responses: [
                "/subscriptions/prepare_payment": Data(
                    prepare.utf8,
                ),
            ],
        )
        let securityDatabase = DSecurityDatabase(
            service: "RobokassaPaymentTests." + UUID().uuidString,
        )
        try await securityDatabase.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: UUID(),
                accessToken: "test-owner-token",
            ),
        )
        defer {
            Task {
                try await securityDatabase.removeBillingIdentity()
            }
        }
        let repository = SubscriptionRobokassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: securityDatabase,
            ),
        )
        let plan = SubscriptionPlan(
            id: "monthly",
            source: .robokassa,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "100 ₽",
            billingPrice: BillingPrice(
                amountMinor: 10000,
                currencyIso2Code: "RUB",
            ),
        )
        let status = try await repository.purchase(
            plan: plan,
            isAutoRenewing: true,
            onPurchasePrepared: { _ in },
        )
        switch status {
        case .completed: break
        case .cancelled, .pending:
            Issue.record(
                "The server already confirmed this payment",
            )
        }
        #expect(
            await http.requests == ["/subscriptions/prepare_payment"],
        )
    }

    @Test(
        arguments: [true, false],
    )
    func paymentIsCheckedOnlyAfterTheBrowserCloses(
        isReturned: Bool,
    ) async throws {
        let id = UUID().uuidString
        let prepare = """
        {"payment":{"id":"\(id)","planId":"monthly","status":"created","confirmationUrl":null,"paymentMethodType":null},
        "checkoutUrl":"https://auth.robokassa.ru/merchant/Invoice/test"}
        """
        let check = """
        {"id":"\(id)","planId":"monthly","status":"pending","confirmationUrl":null,"paymentMethodType":null}
        """
        let http = RobokassaTestHttpClient(
            responses: [
                "/subscriptions/prepare_payment": Data(
                    prepare.utf8,
                ),
                "/subscriptions/check_payment": Data(
                    check.utf8,
                ),
            ],
        )
        var isOpened = false
        var context: SubscriptionPurchaseContextProtocol?
        let securityDatabase = DSecurityDatabase(
            service: "RobokassaPaymentTests." + UUID().uuidString,
        )
        try await securityDatabase.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: UUID(),
                accessToken: "test-owner-token",
            ),
        )
        defer {
            Task {
                try await securityDatabase.removeBillingIdentity()
            }
        }
        let repository = SubscriptionRobokassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: securityDatabase,
            ),
            openCheckout: { url in
                #expect(
                    context != nil,
                )
                #expect(
                    url.absoluteString == "https://auth.robokassa.ru/merchant/Invoice/test",
                )
                #expect(
                    await http.requests == ["/subscriptions/prepare_payment"],
                )
                isOpened = true
                return isReturned
            },
        )
        let plan = SubscriptionPlan(
            id: "monthly",
            source: .robokassa,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "100 ₽",
            billingPrice: BillingPrice(
                amountMinor: 10000,
                currencyIso2Code: "RUB",
            ),
        )
        let outcome = try await repository.purchase(
            plan: plan,
            isAutoRenewing: isReturned,
            onPurchasePrepared: {
                context = $0
            },
        )
        guard case .pending = outcome else {
            Issue.record(
                "Closing the browser must preserve an unresolved payment",
            )
            return
        }
        #expect(
            isOpened,
        )
        #expect(
            await http.requests == ["/subscriptions/prepare_payment", "/subscriptions/check_payment"],
        )
        let body = try #require(
            await http.requestBodies[
                "/subscriptions/prepare_payment",
            ],
        )
        let request = try JSONSerialization.jsonObject(
            with: body,
        ) as? [String: Any]
        #expect(
            request?[
                "isAutoRenewing",
            ] as? Bool == isReturned,
        )
        #expect(
            (request?[
                "price",
            ] as? [String: Any])?[
                "amountMinor",
            ] as? Int == 10000,
        )
    }

    @Test
    func cancellationBeforePurchaseDoesNotCreateAnOrder() async throws {
        let http = RobokassaTestHttpClient(
            responses: [:],
        )
        let securityDatabase = DSecurityDatabase(
            service: "RobokassaPaymentTests." + UUID().uuidString,
        )
        try await securityDatabase.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: UUID(),
                accessToken: "test-owner-token",
            ),
        )
        defer {
            Task {
                try await securityDatabase.removeBillingIdentity()
            }
        }
        let repository = SubscriptionRobokassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: securityDatabase,
            ),
        )
        let plan = SubscriptionPlan(
            id: "monthly",
            source: .robokassa,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "100 ₽",
            billingPrice: BillingPrice(
                amountMinor: 10000,
                currencyIso2Code: "RUB",
            ),
        )
        let task = Task {
            try await repository.purchase(
                plan: plan,
                isAutoRenewing: true,
                onPurchasePrepared: { _ in },
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record(
                "A canceled purchase must not present a form",
            )
        } catch is CancellationError {} catch {
            Issue.record(
                "Unexpected purchase error",
            )
        }
        #expect(
            await http.requests.isEmpty,
        )
    }
}
