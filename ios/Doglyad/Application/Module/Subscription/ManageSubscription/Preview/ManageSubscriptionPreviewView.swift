#if DEBUG
    import Router
    import SwiftUI

    struct ManageSubscriptionPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let scenario: ManageSubscriptionPreviewScenario

        var body: some View {
            let isErrorPresented = switch scenario {
            case .failed, .operationFailed: true
            default: false
            }

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
            .previewError(
                isPresented: isErrorPresented,
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
