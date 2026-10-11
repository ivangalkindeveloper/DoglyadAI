import DoglyadDatabase
import Foundation
import RevenueCat

@MainActor
final class RevenueCatSubscriptionRepository: SubscriptionRepositoryProtocol {
    private let apiKey: String
    private let environment: EnvironmentProtocol
    private let securityDatabase: DSecurityDatabaseProtocol
    private var packagesById: [String: Package] = [:]

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
        switch environment.type {
        case .development:
            Purchases.logLevel = .debug
        case .production:
            Purchases.logLevel = .info
        }
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

    func fetchPlans() async throws -> [SubscriptionPlan] {
        let offerings = try await Purchases.shared.offerings()
        let packages = offerings.current?.availablePackages ?? []
        packagesById = Dictionary(
            uniqueKeysWithValues: packages.map { ($0.identifier, $0) },
        )
        return packages.map { package in
            SubscriptionPlan(
                id: package.identifier,
                productId: package.storeProduct.productIdentifier,
                kind: planKind(
                    package.packageType,
                ),
                price: package.localizedPriceString,
            )
        }
    }

    func purchase(
        plan: SubscriptionPlan,
        configEntitlements: [SubscriptionType: SubscriptionEntitlement],
    ) async throws -> SubscriptionPurchaseOutcome {
        guard let package = packagesById[
            plan.id,
        ],
            package.storeProduct.productIdentifier == plan.productId
        else { throw SubscriptionError.offeringsUnavailable }
        let customerInfo: CustomerInfo? = try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(
                package: package,
            ) { _, info, error, userCancelled in
                if userCancelled {
                    continuation.resume(
                        returning: nil,
                    )
                } else if let error {
                    continuation.resume(
                        throwing: error,
                    )
                } else if let info {
                    continuation.resume(
                        returning: info,
                    )
                } else {
                    continuation.resume(
                        throwing: SubscriptionError.offeringsUnavailable,
                    )
                }
            }
        }
        guard let customerInfo else { return .cancelled }
        return await .completed(
            status(
                from: customerInfo,
                configEntitlements: configEntitlements,
            ),
        )
    }

    func manageSubscription() async throws {
        try await Purchases.shared.showManageSubscriptions()
    }

    func requestRefund() async throws {
        _ = try await Purchases.shared.beginRefundRequestForActiveEntitlement()
    }

    private func planKind(
        _ type: PackageType,
    ) -> SubscriptionPlanKind {
        switch type {
        case .unknown, .custom: .custom
        case .lifetime: .lifetime
        case .annual: .annual
        case .sixMonth: .sixMonth
        case .threeMonth: .threeMonth
        case .twoMonth: .twoMonth
        case .monthly: .monthly
        case .weekly: .weekly
        @unknown default: .custom
        }
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
