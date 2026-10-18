import Foundation

struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let productId: String
    let kind: SubscriptionPlanKind
    let price: String
}
