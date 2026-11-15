@MainActor
final class SubscriptionPaywallPurchaseLoadingState: SubscriptionPaywallContentState {
    let plan: SubscriptionPlan

    init(
        content: SubscriptionPaywallContentState,
        plan: SubscriptionPlan,
    ) {
        self.plan = plan
        super.init(
            copying: content,
        )
    }

    override func equals(
        _ other: SubscriptionPaywallContentState,
    ) -> Bool {
        guard let other = other as? SubscriptionPaywallPurchaseLoadingState else {
            return false
        }
        return super.equals(
            other,
        ) && plan == other.plan
    }
}
