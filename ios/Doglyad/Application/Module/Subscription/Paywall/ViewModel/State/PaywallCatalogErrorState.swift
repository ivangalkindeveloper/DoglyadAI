@MainActor
final class PaywallCatalogErrorState: PaywallStateProtocol, @MainActor Equatable {
    let errorDescription: String

    init(
        errorDescription: String,
    ) {
        self.errorDescription = errorDescription
    }

    static func == (
        lhs: PaywallCatalogErrorState,
        rhs: PaywallCatalogErrorState,
    ) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
