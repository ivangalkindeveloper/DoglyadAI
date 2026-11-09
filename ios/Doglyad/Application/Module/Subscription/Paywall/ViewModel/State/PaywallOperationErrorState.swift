@MainActor
final class PaywallOperationErrorState: PaywallContentState {
    let errorDescription: String
    let previousState: PaywallContentState

    init(
        errorDescription: String,
        previousState: PaywallContentState,
    ) {
        self.errorDescription = errorDescription
        self.previousState = previousState
        super.init(
            copying: previousState,
        )
    }

    override func equals(
        _ other: PaywallContentState,
    ) -> Bool {
        guard let other = other as? PaywallOperationErrorState else {
            return false
        }
        return super.equals(
            other,
        ) && errorDescription == other.errorDescription && previousState == other.previousState
    }
}
