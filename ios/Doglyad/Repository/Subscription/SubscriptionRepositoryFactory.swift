import Foundation
import StoreKit

@MainActor
final class SubscriptionRepositoryFactory {
    private let storeKit: SubscriptionRepositoryProtocol
    private let yooKassa: SubscriptionRepositoryProtocol
    private let getStorefrontCountryCode: () async -> String?

    init(
        storeKit: SubscriptionRepositoryProtocol,
        yooKassa: SubscriptionRepositoryProtocol,
        getStorefrontCountryCode: @escaping () async -> String? = { await Storefront.current?.countryCode },
    ) {
        self.storeKit = storeKit
        self.yooKassa = yooKassa
        self.getStorefrontCountryCode = getStorefrontCountryCode
    }

    func make() async -> SubscriptionRepositoryProtocol {
        let countryCode = await getStorefrontCountryCode()
        return countryCode == "RUS" ? yooKassa : storeKit
    }

    func make(
        plan: SubscriptionPlan,
    ) async throws -> SubscriptionRepositoryProtocol {
        let repository = await make()
        guard repository === make(
            source: plan.source,
        ) else { throw SubscriptionError.offeringsUnavailable }
        return repository
    }

    func make(
        source: SubscriptionSource?,
    ) -> SubscriptionRepositoryProtocol {
        switch source {
        case .yookassa: yooKassa
        case .apple, .none: storeKit
        }
    }
}
