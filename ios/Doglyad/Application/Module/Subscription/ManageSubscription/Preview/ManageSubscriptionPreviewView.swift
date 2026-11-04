#if DEBUG
    import Router
    import SwiftUI

    struct ManageSubscriptionPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let scenario: ManageSubscriptionPreviewScenario

        var body: some View {
            let model = ManageSubscriptionPreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: ManageSubscriptionPreviewFactory.status(
                    for: scenario,
                ),
            )

            ManageSubscriptionScreenView(
                viewModel: model,
            )
            .id(
                scenario,
            )
            .task {
                await ManageSubscriptionPreviewFactory.apply(
                    scenario,
                    to: model,
                )
            }
        }
    }
#endif
