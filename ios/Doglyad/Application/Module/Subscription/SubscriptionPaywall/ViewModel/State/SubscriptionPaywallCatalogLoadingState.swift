@MainActor
final class SubscriptionPaywallCatalogLoadingState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    let previousState: SubscriptionPaywallContentState?

    init(
        previousState: SubscriptionPaywallContentState? = nil,
    ) {
        self.previousState = previousState
    }

    static func == (
        lhs: SubscriptionPaywallCatalogLoadingState,
        rhs: SubscriptionPaywallCatalogLoadingState,
    ) -> Bool {
        lhs.previousState == rhs.previousState
    }
}
