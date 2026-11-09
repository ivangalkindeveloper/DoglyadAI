#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SettingsPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SettingsStateProtocol
        var reportsCount: Int? = 12

        var body: some View {
            let model = SettingsViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    ModulePreviewFactory.subscription
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
            )

            model.reportsCount = reportsCount

            model.preparePreview(
                state: state,
            )
            return SettingsScreenView(
                viewModel: model,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
