@MainActor
class SubscriptionManageSuccessState: SubscriptionManageStateProtocol, @MainActor Equatable {
    let catalog: BillingProductsResponse

    init(
        catalog: BillingProductsResponse,
    ) {
        self.catalog = catalog
    }

    func equals(
        _ other: SubscriptionManageSuccessState,
    ) -> Bool {
        type(
            of: self,
        ) == type(
            of: other,
        ) && catalog == other.catalog
    }

    static func == (
        lhs: SubscriptionManageSuccessState,
        rhs: SubscriptionManageSuccessState,
    ) -> Bool {
        lhs.equals(
            rhs,
        )
    }
}
