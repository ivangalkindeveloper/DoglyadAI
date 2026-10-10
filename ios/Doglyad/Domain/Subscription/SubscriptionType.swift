import Foundation

enum SubscriptionType: String, Codable, Equatable, Comparable {
    case base
    case pro

    /// The higher the priority, the more expensive/capable the subscription.
    private var priority: Int {
        switch self {
        case .base: 0
        case .pro: 1
        }
    }

    static func < (
        lhs: SubscriptionType,
        rhs: SubscriptionType,
    ) -> Bool {
        lhs.priority < rhs.priority
    }
}
