struct BillingRecoveredAccessResponse: Decodable {
    let identity: BillingIdentityResponse
    let subscription: BillingStatusResponse?

    init(
        identity: BillingIdentityResponse,
        subscription: BillingStatusResponse?,
    ) {
        self.identity = identity
        self.subscription = subscription
    }
}
