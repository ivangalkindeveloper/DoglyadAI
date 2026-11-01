import Foundation

struct SubscriptionTier: Decodable, Identifiable, Equatable {
    let id: SubscriptionType
    let title: String
    let features: [String]
}
