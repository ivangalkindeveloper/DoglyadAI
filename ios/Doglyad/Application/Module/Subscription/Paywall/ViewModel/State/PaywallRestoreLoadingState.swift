@MainActor
final class PaywallRestoreLoadingState: PaywallContentState {
    let previousState: PaywallContentState

    init(
        previousState: PaywallContentState,
    ) {
        self.previousState = previousState
        super.init(
            copying: previousState,
        )
    }

    override func equals(
        _ other: PaywallContentState,
    ) -> Bool {
        guard let other = other as? PaywallRestoreLoadingState else {
            return false
        }
        return super.equals(
            other,
        ) && previousState == other.previousState
    }
}
