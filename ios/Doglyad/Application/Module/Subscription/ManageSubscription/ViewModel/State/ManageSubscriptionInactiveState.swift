@MainActor
final class ManageSubscriptionInactiveState: ManageSubscriptionContentState {
    let notice: String?

    init(
        catalog: BillingProductsResponse,
        notice: String? = nil,
    ) {
        self.notice = notice
        super.init(
            catalog: catalog,
        )
    }

    override func equals(
        _ other: ManageSubscriptionContentState,
    ) -> Bool {
        guard let other = other as? ManageSubscriptionInactiveState else { return false }
        return super.equals(
            other,
        ) && notice == other.notice
    }
}
