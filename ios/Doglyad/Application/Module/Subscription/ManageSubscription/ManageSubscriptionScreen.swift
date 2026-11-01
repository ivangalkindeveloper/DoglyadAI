import Router
import SwiftUI

struct ManageSubscriptionScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: ManageSubscriptionArguments?

    var body: some View {
        ManageSubscriptionScreenView(
            viewModel: ManageSubscriptionViewModel(
                container: container,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getSettingsAI: { [subscriptionViewModel] in subscriptionViewModel.resolveSettingsAI() },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in await subscriptionViewModel.refreshStatus() },
                arguments: arguments,
                manageSubscription: { [subscriptionViewModel] in try await subscriptionViewModel.manageSubscription() },
                restorePurchases: { [subscriptionViewModel] in try await subscriptionViewModel.restorePurchases() },
                requestRefund: { [subscriptionViewModel] in try await subscriptionViewModel.requestRefund() },

            ),
        )
    }
}

#if DEBUG
    #Preview(
        "Pro · App Store",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .applePro,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .applePro,
            to: model,
        ) }
    }

    #Preview(
        "Base · ЮКасса",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .yooKassaBase,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .yooKassaBase,
            to: model,
        ) }
    }

    #Preview(
        "Pro · ЮКасса",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .yooKassaPro,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .yooKassaPro,
            to: model,
        ) }
    }

    #Preview(
        "Автопродление отключено",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .renewalOff,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .renewalOff,
            to: model,
        ) }
    }

    #Preview(
        "Без подписки",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .inactive,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .inactive,
            to: model,
        ) }
    }

    #Preview(
        "Загрузка",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .loading,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .loading,
            to: model,
        ) }
    }

    #Preview(
        "Обновление подписки",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .updating,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .updating,
            to: model,
        ) }
    }

    #Preview(
        "Ошибка загрузки",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .failed,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .failed,
            to: model,
        ) }
    }

    #Preview(
        "Ошибка операции",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "ru",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .operationFailed,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .operationFailed,
            to: model,
        ) }
    }

    #Preview(
        "Pro · English",
    ) {
        let container = ManageSubscriptionPreviewFactory.makeContainer(
            code: "en",
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .settings,
            ),
        )
        let model = ManageSubscriptionPreviewFactory.makeViewModel(
            container: container,
            router: router,
            status: ManageSubscriptionPreviewFactory.status(
                for: .applePro,
            ),
        )
        ManageSubscriptionScreenView(
            viewModel: model,
        ).previewable(
            container: container,
            router: router,
        )
        .task { await ManageSubscriptionPreviewFactory.apply(
            .applePro,
            to: model,
        ) }
    }
#endif
