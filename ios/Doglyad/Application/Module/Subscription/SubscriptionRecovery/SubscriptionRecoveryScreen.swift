import Router
import SwiftUI

struct SubscriptionRecoveryScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: SubscriptionRecoveryArguments?

    var body: some View {
        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.observeStatus(
                        $0,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] in
                    subscriptionViewModel.update(
                        status: $0,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
                arguments: arguments,
                createRecoveryKey: { [subscriptionViewModel] in
                    try await subscriptionViewModel.createRecoveryKey()
                },
                recover: { [subscriptionViewModel] in
                    try await subscriptionViewModel.recover(
                        key: $0,
                    )
                },
            ),
        )
    }
}

#if DEBUG
    #Preview(
        "Начальное состояние",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer()
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .manageSubscription,
            ),
        )

        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: router,
                state: SubscriptionRecoveryDefaultState(),
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }

    #Preview(
        "Создан ключ",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer()
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .manageSubscription,
            ),
        )

        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: router,
                state: SubscriptionRecoveryKeyState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }

    #Preview(
        "Восстановление",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer()
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .manageSubscription,
            ),
        )

        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: router,
                state: SubscriptionRecoveryLoadingState(
                    previousState: SubscriptionRecoveryKeyState(
                        key: "Preview-MixedCase-Recovery-Key",
                    ),
                ),
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }

    #Preview(
        "Ошибка",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer()
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .manageSubscription,
            ),
        )

        SubscriptionRecoveryScreenView(
            viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                container: container,
                router: router,
                state: SubscriptionRecoveryFailedState(
                    previousState: SubscriptionRecoveryDefaultState(),
                    errorDescription: container.l10n.text(
                        .subscriptionRecoveryFailedDescription,
                    ),
                ),
            ),
        )
        .previewable(
            container: container,
            router: router,
        )
    }
#endif
