@MainActor
final class SubscriptionPaywallCatalogErrorState: SubscriptionPaywallStateProtocol, @MainActor Equatable {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: SubscriptionPaywallCatalogErrorState,
        rhs: SubscriptionPaywallCatalogErrorState,
    ) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
