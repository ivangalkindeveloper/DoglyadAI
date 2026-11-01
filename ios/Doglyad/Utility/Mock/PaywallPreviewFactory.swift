#if DEBUG
    import Combine
    import Foundation
    import Router

    @MainActor
    enum PaywallPreviewFactory {
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
                subscriptionRepositoryFactory: SubscriptionRepositoryFactory(
                    storeKit: repository,
                    yooKassa: repository,
                    getStorefrontCountryCode: {
                        "RUS"
                    },
                ),
            )
        }

        static func makeViewModel(
            container: DependencyContainer,
            router: DRouter,
        ) -> PaywallViewModel {
            PaywallViewModel(
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
                purchase: { _ in
                    .cancelled
                },
                restorePurchases: {
                    nil
                },
                checkPurchase: {
                    .pending
                },
            )
        }
    }
#endif
