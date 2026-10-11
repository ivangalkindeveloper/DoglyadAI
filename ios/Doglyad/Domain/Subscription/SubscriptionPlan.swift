import Foundation

struct SubscriptionPlan: Identifiable {
    let id: String
    let productId: String
    let kind: SubscriptionPlanKind
    let price: String
}
