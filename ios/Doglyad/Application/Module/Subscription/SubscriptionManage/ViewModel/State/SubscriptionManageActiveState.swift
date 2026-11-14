@MainActor
final class SubscriptionManageActiveState: SubscriptionManageSuccessState {
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
        _ other: SubscriptionManageSuccessState,
    ) -> Bool {
        guard let other = other as? SubscriptionManageActiveState else {
            return false
        }
        return super.equals(
            other,
        ) && status == other.status && tier == other.tier
    }
}
