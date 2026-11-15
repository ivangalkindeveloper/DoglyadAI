@MainActor
final class SubscriptionPaywallOperationErrorState: SubscriptionPaywallContentState {
    let errorDescription: String
    let previousState: SubscriptionPaywallContentState

    init(
        errorDescription: String,
        previousState: SubscriptionPaywallContentState,
    ) {
        self.errorDescription = errorDescription
        self.previousState = previousState
        super.init(
            copying: previousState,
        )
    }

    override func equals(
        _ other: SubscriptionPaywallContentState,
    ) -> Bool {
        guard let other = other as? SubscriptionPaywallOperationErrorState else {
            return false
        }
        return super.equals(
            other,
        ) && errorDescription == other.errorDescription && previousState == other.previousState
    }
}
