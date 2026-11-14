@MainActor
final class SubscriptionManageInactiveState: SubscriptionManageSuccessState {
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
        _ other: SubscriptionManageSuccessState,
    ) -> Bool {
        guard let other = other as? SubscriptionManageInactiveState else {
            return false
        }
        return super.equals(
            other,
        ) && notice == other.notice
    }
}
