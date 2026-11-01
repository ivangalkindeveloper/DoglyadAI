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
            // Canvas reads current tariffs from the backend source without HTTP or StoreKit.
            let catalogURL = URL(
                filePath: #filePath,
            )
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(
                path: "backend/main/config/development/billing.json",
            )
            guard let code = locale.language.languageCode?.identifier,
                  let document = try JSONSerialization.jsonObject(
                      with: Data(
                          contentsOf: catalogURL,
                      ),
                  ) as? [String: Any],
                  let tiers = document[
                      "tiers",
                  ] as? [[String: Any]],
                  let products = document[
                      "products",
                  ] as? [[String: Any]],
                  let strings = try JSONSerialization.jsonObject(
                      with: Data(
                          contentsOf: catalogURL.deletingLastPathComponent().appending(
                              path: "\(code)/l10n.json",
                          ),
                      ),
                  ) as? [String: String]
            else {
                throw URLError(
                    .cannotParseResponse,
                )
            }
            let localizedTiers = try tiers.map { tier in
                guard let id = tier[
                    "id",
                ] as? String,
                    let titleKey = tier[
                        "titleLocaleKey",
                    ] as? String,
                    let title = strings[
                        titleKey,
                    ],
                    let featureKeys = tier[
                        "featureLocaleKeys",
                    ] as? [String]
                else { throw URLError(
                    .cannotParseResponse,
                ) }
                let features = try featureKeys.map { key in
                    guard let text = strings[
                        key,
                    ] else { throw URLError(
                        .cannotParseResponse,
                    ) }
                    return text
                }
                return ["id": id, "title": title, "features": features]
            }
            let localizedProducts = try products.map { product in
                guard let titleKey = product[
                    "titleLocaleKey",
                ] as? String,
                    let priceKey = product[
                        "priceTemplateLocaleKey",
                    ] as? String,
                    let title = strings[
                        titleKey,
                    ], let priceTemplate = strings[
                        priceKey,
                    ]
                else {
                    throw URLError(
                        .cannotParseResponse,
                    )
                }
                var localized = product
                localized[
                    "title",
                ] = title
                localized[
                    "priceTemplate",
                ] = priceTemplate
                return localized
            }
            return try JSONDecoder().decode(
                BillingProductsResponse.self,
                from: JSONSerialization.data(
                    withJSONObject: ["tiers": localizedTiers, "products": localizedProducts],
                ),
            )
        }

        func fetchCatalog() async throws -> SubscriptionCatalog {
            let catalog = try await fetchProducts()
            let plans = catalog.products.map { plan in
                SubscriptionPlan(
                    id: plan.id,
                    source: .yookassa,
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
            onPurchasePrepared _: @escaping (SubscriptionPurchaseReference) -> Void,
        ) async throws -> SubscriptionPurchaseOutcome { .cancelled }

        func restorePurchases() async throws -> Bool { false }

        func synchronizeCurrentEntitlements() async throws -> Bool { false }

        func observeChanges(
            _: @escaping (Result<SubscriptionTransactionUpdate, Error>) -> Void,
        ) async throws {}

        func manageSubscription() async throws {}

        func requestRefund() async throws {}
    }
#endif
