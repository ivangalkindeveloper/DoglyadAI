@MainActor
final class PaywallPurchasingState: PaywallContentState {
    let plan: SubscriptionPlan

    init(
        content: PaywallContentState,
        plan: SubscriptionPlan,
    ) {
        self.plan = plan
        super.init(
            copying: content,
        )
    }

    override func equals(
        _ other: PaywallContentState,
    ) -> Bool {
        guard let other = other as? PaywallPurchasingState else {
            return false
        }
        return super.equals(
            other,
        ) && plan == other.plan
    }
}
