import Foundation

struct BillingProductResponse: Decodable, Equatable {
    let id: String
    let entitlement: SubscriptionType
    let period: SubscriptionPeriod
    let price: BillingPrice
    let title: String
    let priceTemplate: String

    func formattedPrice(
        _ price: String,
    ) -> String {
        priceTemplate.replacingOccurrences(
            of: "{price}",
            with: price,
        )
    }
}
