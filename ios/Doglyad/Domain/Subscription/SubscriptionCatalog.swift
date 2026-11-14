import Foundation

struct SubscriptionCatalog: Equatable {
    let tiers: [SubscriptionTier]
    let plans: [SubscriptionPlan]

    init(
        tiers: [SubscriptionTier],
        plans: [SubscriptionPlan],
    ) {
        self.tiers = tiers
        self.plans = plans
    }
}
