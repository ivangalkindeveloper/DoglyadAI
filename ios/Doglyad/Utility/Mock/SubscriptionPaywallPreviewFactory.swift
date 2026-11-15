#if DEBUG
    import Combine
    import DoglyadUI
    import Foundation
    import Router

    @MainActor
    enum SubscriptionPaywallPreviewFactory {
        static let storeKitContent = SubscriptionPaywallSuccessState(
            tiers: ModulePreviewFactory.development.products.tiers,
            plans: ModulePreviewFactory.development.products.products.map { product in
                SubscriptionPlan(
                    id: product.id,
                    source: .apple,
                    type: product.entitlement,
                    period: product.period,
                    title: product.title,
                    price: product.formattedPrice(
                        999.formattedCurrencyFromMinorUnits(
                            code: "USD",
                            locale: Locale(
                                identifier: "ru",
                            ),
                        ),
                    ),
                )
            },
            selectedType: .pro,
            selectedPlanID: ModulePreviewFactory.subscriptionPaywallPlan.id,
        )

        static func makeContainer(
            code: String = "ru",
        ) -> DependencyContainer {
            let l10n = L10NPreviewFactory.make(
                code: code,
            )
            let repository = SubscriptionPreviewRepository(
                locale: l10n.locale,
            )
            return DependencyContainer.makePreviewable(
                l10n: l10n,
                subscriptionRepositoryFactory: SubscriptionPreviewRepositoryFactory(
                    repository: repository,
                ),
            )
        }

        static func makeViewModel(
            container: DependencyContainer,
            router: DRouter,
        ) -> SubscriptionPaywallViewModel {
            SubscriptionPaywallViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                arguments: nil,
                purchase: { _, _ in
                    .cancelled
                },
                restorePurchases: {
                    .completed(
                        isOwnerChanged: false,
                    )
                },
                checkPurchase: {
                    .pending
                },
            )
        }
    }
#endif
