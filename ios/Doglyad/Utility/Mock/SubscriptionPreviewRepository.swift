#if DEBUG
    import Foundation

    @MainActor
    final class SubscriptionPreviewRepository: SubscriptionRepositoryProtocol {
        private let locale: Locale

        init(
            locale: Locale,
        ) {
            self.locale = locale
        }

        func fetchProducts() async throws -> BillingProductsResponse {
            DevelopmentPreviewFactory.make(
                code: locale.language.languageCode?.identifier ?? "ru",
            ).products
        }

        func fetchCatalog() async throws -> SubscriptionCatalog {
            let catalog = try await fetchProducts()
            let plans = catalog.products.map { plan in
                SubscriptionPlan(
                    id: plan.id,
                    source: .robokassa,
                    type: plan.entitlement,
                    period: plan.period,
                    title: plan.title,
                    price: plan.formattedPrice(
                        plan.price.amountMinor.formattedCurrencyFromMinorUnits(
                            code: plan.price.currencyIso2Code,
                            locale: locale,
                        ),
                    ),
                )
            }
            return SubscriptionCatalog(
                tiers: catalog.tiers,
                plans: plans,
            )
        }

        func purchase(
            plan _: SubscriptionPlan,
            isAutoRenewing _: Bool,
            onPurchasePrepared _: @escaping (SubscriptionPurchaseContextProtocol) -> Void,
        ) async throws -> SubscriptionPurchaseOutcome {
            .cancelled
        }

        func restorePurchases() async throws -> SubscriptionRestoreStrategy {
            .recoveryKeyRequired
        }

        func synchronizeCurrentEntitlements() async throws -> Bool {
            false
        }

        func observeChanges(
            _: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
        ) async throws {}

        func manageSubscription() async throws {}

        func requestRefund() async throws {}
    }
#endif
