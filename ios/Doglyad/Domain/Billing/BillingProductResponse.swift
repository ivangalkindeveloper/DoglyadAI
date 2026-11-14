import Foundation

struct BillingProductResponse: Decodable, Equatable {
    let id: String
    let entitlement: SubscriptionType
    let period: SubscriptionPeriod
    let price: BillingPrice
    let title: String
    let priceTemplate: String

    init(
        id: String,
        entitlement: SubscriptionType,
        period: SubscriptionPeriod,
        price: BillingPrice,
        title: String,
        priceTemplate: String,
    ) {
        self.id = id
        self.entitlement = entitlement
        self.period = period
        self.price = price
        self.title = title
        self.priceTemplate = priceTemplate
    }

    func formattedPrice(
        _ price: String,
    ) -> String {
        priceTemplate.replacingOccurrences(
            of: "{price}",
            with: price,
        )
    }
}
