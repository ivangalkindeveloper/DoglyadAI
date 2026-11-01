@MainActor
final class PaywallOperationFailedState: PaywallContentState {
    let errorDescription: String
    let previousState: PaywallContentState

    init(
        previousState: PaywallContentState,
        errorDescription: String,
    ) {
        self.previousState = previousState
        self.errorDescription = errorDescription
        super.init(
            copying: previousState,
        )
    }

    override func equals(
        _ other: PaywallContentState,
    ) -> Bool {
        guard let other = other as? PaywallOperationFailedState else { return false }
        return super.equals(
            other,
        ) && errorDescription == other.errorDescription && previousState == other.previousState
    }
}
