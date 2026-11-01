@MainActor
class ManageSubscriptionContentState: ManageSubscriptionStateProtocol, @MainActor Equatable {
    let catalog: BillingProductsResponse

    init(
        catalog: BillingProductsResponse,
    ) {
        self.catalog = catalog
    }

    func equals(
        _ other: ManageSubscriptionContentState,
    ) -> Bool {
        type(
            of: self,
        ) == type(
            of: other,
        ) && catalog == other.catalog
    }

    static func == (
        lhs: ManageSubscriptionContentState,
        rhs: ManageSubscriptionContentState,
    ) -> Bool {
        lhs.equals(
            rhs,
        )
    }
}
