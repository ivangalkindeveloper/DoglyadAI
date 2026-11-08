@MainActor
final class PaywallCatalogLoadingState: PaywallStateProtocol, @MainActor Equatable {
    let previousState: PaywallContentState?

    init(
        previousState: PaywallContentState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: PaywallCatalogLoadingState,
        rhs: PaywallCatalogLoadingState,
    ) -> Bool {
        lhs.previousState == rhs.previousState
    }
}
