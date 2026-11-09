#if DEBUG
    import Router
    import SwiftUI

    struct SubscriptionRecoveryPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionRecoveryStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as SubscriptionRecoveryErrorState: true
            default: false
            }

            SubscriptionRecoveryScreenView(
                viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                    container: container,
                    router: router,
                    state: state,
                ),
            )
            .previewError(
                isPresented: isErrorPresented,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
