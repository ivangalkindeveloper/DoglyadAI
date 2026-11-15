@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct SubscriptionCatalogTests {
    init() {}

    @Test(
        arguments: [SubscriptionPeriod.weekly, .monthly, .sixMonth, .annual],
    )
    func robokassaUsesTheServerPeriodWithoutFallingBackToMonthly(
        period: SubscriptionPeriod,
    ) async throws {
        let json = """
        {"tiers":[{"id":"pro","title":"Server tier","features":["Server feature"]}],"products":[{"id":"robo-plan","title":"Custom server title","priceTemplate":"Pay {price} for this offer","entitlement":"pro","period":"\(period.rawValue)","price":{"amountMinor":32135,"oldAmountMinor":50000,"currencyIso2Code":"RUB"}}]}
        """
        let http = RobokassaTestHttpClient(
            responses: ["/subscriptions/plans": Data(
                json.utf8,
            )],
        )
        let repository = SubscriptionRobokassaRepository(
            backend: SubscriptionBackendRepository(
                httpClient: http,
                securityDatabase: DSecurityDatabase(),
                getAcceptedLegalDocumentDate: {
                    Date(
                        timeIntervalSince1970: 1794700800,
                    )
                },
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
            plans.first?.id == "robo-plan",
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
            plans.first?.oldPrice == 50000.formattedCurrencyFromMinorUnits(
                code: "RUB",
            ),
        )
        #expect(
            plans.first?.billingPrice?.amountMinor == 32135,
        )
        #expect(
            plans.first?.billingPrice?.oldAmountMinor == 50000,
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
        let http = RobokassaTestHttpClient(
            responses: ["/subscriptions/plans": Data(
                json.utf8,
            )],
        )
        let backend = SubscriptionBackendRepository(
            httpClient: http,
            securityDatabase: DSecurityDatabase(),
            getAcceptedLegalDocumentDate: {
                Date(
                    timeIntervalSince1970: 1794700800,
                )
            },
        )
        let catalog = try await backend.fetchPlans()
        #expect(
            catalog.products.isEmpty,
        )
        #expect(
            try await SubscriptionRobokassaRepository(
                backend: backend,
            ).fetchCatalog().plans.isEmpty,
        )
    }
}
