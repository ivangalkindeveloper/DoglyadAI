@MainActor
final class SubscriptionRepositoryFactory: SubscriptionRepositoryFactoryProtocol {
    private let backend: SubscriptionBackendRepositoryProtocol
    private let getStorefrontCountryCode: () async -> String?

    init(
        backend: SubscriptionBackendRepositoryProtocol,
        getStorefrontCountryCode: @escaping () async -> String?,
    ) {
        self.backend = backend
        self.getStorefrontCountryCode = getStorefrontCountryCode
    }

    func make() async -> SubscriptionRepositoryProtocol {
        let countryCode = await getStorefrontCountryCode()
        return countryCode == "RUS"
            ? SubscriptionRobokassaRepository(
                backend: backend,
            )
            : SubscriptionStoreKitRepository(
                backend: backend,
            )
    }
}
