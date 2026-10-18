import Foundation

@MainActor
final class SubscriptionPaywallPurchasingState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    let plan: SubscriptionPlan

    init(
        plan: SubscriptionPlan,
    ) {
        self.plan = plan
    }

    static func == (
        lhs: SubscriptionPaywallPurchasingState,
        rhs: SubscriptionPaywallPurchasingState,
    ) -> Bool {
        lhs.plan == rhs.plan
    }
}
