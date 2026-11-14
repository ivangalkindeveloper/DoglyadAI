import Foundation

struct SubscriptionTier: Decodable, Identifiable, Equatable {
    let id: SubscriptionType
    let title: String
    let features: [String]

    init(
        id: SubscriptionType,
        title: String,
        features: [String],
    ) {
        self.id = id
        self.title = title
        self.features = features
    }
}
