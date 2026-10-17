import Foundation

@MainActor
final class SubscriptionPaywallPurchasingState: SubscriptionPaywallStateProtocol {
    let plan: SubscriptionPlan

    init(
        plan: SubscriptionPlan,
    ) {
        self.plan = plan
    }
}
