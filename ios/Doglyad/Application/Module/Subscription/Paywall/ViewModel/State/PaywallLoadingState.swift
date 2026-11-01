@MainActor
final class PaywallLoadingState: PaywallStateProtocol, @MainActor Equatable {
    let previousState: PaywallContentState?

    init(
        previousState: PaywallContentState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: PaywallLoadingState,
        rhs: PaywallLoadingState,
    ) -> Bool {
        lhs.previousState == rhs.previousState
    }
}
