struct BillingAutoRenewalRequest: Encodable, Sendable {
    let isAutoRenewing: Bool

    init(
        isAutoRenewing: Bool,
    ) {
        self.isAutoRenewing = isAutoRenewing
    }
}
