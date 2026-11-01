import Foundation

struct SubscriptionCatalog: Equatable {
    let tiers: [SubscriptionTier]
    let plans: [SubscriptionPlan]
}
