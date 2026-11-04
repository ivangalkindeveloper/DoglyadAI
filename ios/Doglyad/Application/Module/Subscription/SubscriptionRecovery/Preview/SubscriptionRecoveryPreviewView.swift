#if DEBUG
    import Router
    import SwiftUI

    struct SubscriptionRecoveryPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionRecoveryStateProtocol

        var body: some View {
            SubscriptionRecoveryScreenView(
                viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                    container: container,
                    router: router,
                    state: state,
                ),
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
