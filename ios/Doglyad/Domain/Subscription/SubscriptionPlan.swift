import Foundation

struct SubscriptionPlan: Identifiable, Equatable {
    let id: String
    let source: SubscriptionSource
    let type: SubscriptionType
    let period: SubscriptionPeriod
    let title: String
    let price: String
}
