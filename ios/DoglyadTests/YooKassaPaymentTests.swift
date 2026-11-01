@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct YooKassaPaymentTests {
    @Test
    func alreadyConfirmedPaymentIsRecoveredWithoutOpeningPaymentForm() async throws {
        let id = UUID().uuidString
        let prepare = """
        {"payment":{"id":"\(id)","planId":"monthly","status":"pending","confirmationUrl":"https://yookassa.ru/confirm","paymentMethodType":"bank_card"},
        "shopId":"123","clientApplicationKey":"test-only","shopName":"Doglyad","description":"Pro monthly",
        "termsVersion":"test-v1","price":{"amountMinor":10000,"currencyIso2Code":"RUB"}}
        """
        let check = """
        {"id":"\(id)","planId":"monthly","status":"succeeded","confirmationUrl":null,"paymentMethodType":"bank_card"}
        """
        let http = YooKassaTestHttpClient(
            responses: [
                "/subscriptions/prepare_payment": Data(
                    prepare.utf8,
                ),
                "/subscriptions/check_payment": Data(
                    check.utf8,
                ),
            ],
        )
        let repository = SubscriptionYooKassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: DSecurityDatabase(),
            ),
        )
        let plan = SubscriptionPlan(
            id: "monthly",
            source: .yookassa,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "100 ₽",
        )
        let status = try await repository.purchase(
            plan: plan,
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
            await http.requests == ["/subscriptions/prepare_payment", "/subscriptions/check_payment"],
        )
    }

    @Test
    func cancellationBeforePurchaseDoesNotCreateAnOrder() async {
        let http = YooKassaTestHttpClient(
            responses: [:],
        )
        let repository = SubscriptionYooKassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: DSecurityDatabase(),
            ),
        )
        let plan = SubscriptionPlan(
            id: "monthly",
            source: .yookassa,
            type: .pro,
            period: .monthly,
            title: "Pro monthly",
            price: "100 ₽",
        )
        let task = Task {
            try await repository.purchase(
                plan: plan,
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
