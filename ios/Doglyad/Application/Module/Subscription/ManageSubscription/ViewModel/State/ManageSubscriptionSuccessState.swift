@MainActor
class ManageSubscriptionSuccessState: ManageSubscriptionStateProtocol, @MainActor Equatable {
    let catalog: BillingProductsResponse

    init(
        catalog: BillingProductsResponse,
    ) {
        self.catalog = catalog
    }

    func equals(
        _ other: ManageSubscriptionSuccessState,
    ) -> Bool {
        type(
            of: self,
        ) == type(
            of: other,
        ) && catalog == other.catalog
    }

    static func == (
        lhs: ManageSubscriptionSuccessState,
        rhs: ManageSubscriptionSuccessState,
    ) -> Bool {
        lhs.equals(
            rhs,
        )
    }
}
