struct BillingProductsResponse: Decodable, Equatable {
    let products: [BillingProductResponse]
    let tiers: [SubscriptionTier]
}
