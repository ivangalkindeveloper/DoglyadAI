@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct SubscriptionCatalogTests {
    @Test(
        arguments: [SubscriptionPeriod.weekly, .monthly, .sixMonth, .annual],
    )
    func yooKassaUsesTheServerPeriodWithoutFallingBackToMonthly(
        period: SubscriptionPeriod,
    ) async throws {
        let json = """
        {"tiers":[{"id":"pro","title":"Server tier","features":["Server feature"]}],"products":[{"id":"yoo-plan","title":"Custom server title","priceTemplate":"Pay {price} for this offer","entitlement":"pro","period":"\(period.rawValue)","price":{"amountMinor":32135,"currencyIso2Code":"RUB"}}]}
        """
        let http = YooKassaTestHttpClient(
            responses: ["/subscriptions/plans": Data(
                json.utf8,
            )],
        )
        let repository = SubscriptionYooKassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: DSecurityDatabase(),
            ),
        )
        let offer = try await repository.fetchCatalog()
        let plans = offer.plans
        #expect(
            offer.tiers == [SubscriptionTier(
                id: .pro,
                title: "Server tier",
                features: ["Server feature"],
            )],
        )
        #expect(
            plans.count == 1,
        )
        #expect(
            plans.first?.id == "yoo-plan",
        )
        #expect(
            plans.first?.period == period,
        )
        #expect(
            plans.first?.type == .pro,
        )
        #expect(
            plans.first?.title == "Custom server title",
        )
        #expect(
            plans.first?.price.hasPrefix(
                "Pay ",
            ) == true && plans.first?.price.hasSuffix(
                " for this offer",
            ) == true,
        )
        #expect(
            plans.first?.price.contains(
                "{price}",
            ) == false,
        )
    }

    @Test
    func emptySharedCatalogContainsNoOffers() async throws {
        let json = """
        {"tiers":[{"id":"pro","title":"Server tier","features":["Server feature"]}],"products":[]}
        """
        let http = YooKassaTestHttpClient(
            responses: ["/subscriptions/plans": Data(
                json.utf8,
            )],
        )
        let backend = SubscriptionBackendRepository(
            httpClient: http,
            securityDatabase: DSecurityDatabase(),
        )
        let catalog = try await backend.fetchPlans()
        #expect(
            catalog.products.isEmpty,
        )
        #expect(
            try await SubscriptionYooKassaRepository(
                backend: backend,
            ).fetchCatalog().plans.isEmpty,
        )
    }
}
