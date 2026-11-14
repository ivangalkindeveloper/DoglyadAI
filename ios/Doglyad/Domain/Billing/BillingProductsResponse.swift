struct BillingProductsResponse: Decodable, Equatable {
    let products: [BillingProductResponse]
    let tiers: [SubscriptionTier]

    init(
        products: [BillingProductResponse],
        tiers: [SubscriptionTier],
    ) {
        self.products = products
        self.tiers = tiers
    }
}
