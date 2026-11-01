@MainActor
final class ManageSubscriptionActiveState: ManageSubscriptionContentState {
    let status: SubscriptionStatus
    let tier: SubscriptionTier

    init(
        catalog: BillingProductsResponse,
        status: SubscriptionStatus,
        tier: SubscriptionTier,
    ) {
        self.status = status
        self.tier = tier
        super.init(
            catalog: catalog,
        )
    }

    var planTitle: String? {
        catalog.products.first {
            $0.id == status.planId
        }?.title
    }

    override func equals(
        _ other: ManageSubscriptionContentState,
    ) -> Bool {
        guard let other = other as? ManageSubscriptionActiveState else {
            return false
        }
        return super.equals(
            other,
        ) && status == other.status && tier == other.tier
    }
}
