import DoglyadDatabase
import Foundation
import RevenueCat

@MainActor
final class RevenueCatSubscriptionRepository: SubscriptionRepositoryProtocol {
    private let apiKey: String
    private let environment: EnvironmentProtocol
    private let securityDatabase: DSecurityDatabaseProtocol

    init(
        apiKey: String,
        environment: EnvironmentProtocol,
        securityDatabase: DSecurityDatabaseProtocol,
    ) {
        self.apiKey = apiKey
        self.environment = environment
        self.securityDatabase = securityDatabase
    }

    func configure() {
        Purchases.logLevel = environment.type == .development ? .debug : .info
        Purchases.configure(
            withAPIKey: apiKey,
            appUserID: nil,
            purchasesAreCompletedBy: .revenueCat,
            storeKitVersion: .storeKit2,
        )
    }

    func cachedStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        guard let customerInfo = Purchases.shared.cachedCustomerInfo else { return nil }
        return await status(
            from: customerInfo,
            configEntitlements: configEntitlements,
        )
    }

    func fetchStatus(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        let customerInfo = try await Purchases.shared.customerInfo()
        return await status(
            from: customerInfo,
            configEntitlements: configEntitlements,
        )
    }

    func restorePurchases(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        let customerInfo = try await Purchases.shared.restorePurchases()
        return await status(
            from: customerInfo,
            configEntitlements: configEntitlements,
        )
    }

    func incrementRequestCount(
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionStatus? {
        try? await securityDatabase.incrementRequestCount()
        let customerInfo = try await Purchases.shared.customerInfo()
        return await status(
            from: customerInfo,
            configEntitlements: configEntitlements,
        )
    }

    private func status(
        from customerInfo: CustomerInfo,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async -> SubscriptionStatus? {
        guard let subscriptionType = customerInfo.entitlements.active.keys
            .compactMap(
                { SubscriptionType(
                    rawValue: $0,
                ) },
            )
            .filter(
                { configEntitlements[
                    $0,
                ] != nil },
            )
            .max(),
            let entitlement = configEntitlements[
                subscriptionType,
            ]
        else {
            return nil
        }
        let availableCountPerDay = await remainingRequestCount(
            limit: entitlement.requestCountPerDay,
        )
        return SubscriptionStatus(
            type: subscriptionType,
            entitlement: entitlement,
            availableCountPerDay: availableCountPerDay,
        )
    }

    private func remainingRequestCount(
        limit: Int,
    ) async -> Int {
        await securityDatabase.fetchRequestLimit { requestLimit in
            guard let requestLimit,
                  Calendar.current.isDateInToday(
                      requestLimit.date,
                  )
            else { return limit }
            return max(
                limit - requestLimit.count,
                0,
            )
        }
    }
}
