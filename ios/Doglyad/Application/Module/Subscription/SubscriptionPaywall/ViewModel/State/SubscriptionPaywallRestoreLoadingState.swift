@MainActor
final class SubscriptionPaywallRestoreLoadingState: SubscriptionPaywallContentState {
    let previousState: SubscriptionPaywallContentState

    init(
        previousState: SubscriptionPaywallContentState,
    ) {
        self.previousState = previousState
        super.init(
            copying: previousState,
        )
    }

    override func equals(
        _ other: SubscriptionPaywallContentState,
    ) -> Bool {
        guard let other = other as? SubscriptionPaywallRestoreLoadingState else {
            return false
        }
        return super.equals(
            other,
        ) && previousState == other.previousState
    }
}
