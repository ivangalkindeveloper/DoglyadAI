#if DEBUG
    import Router
    import SwiftUI

    struct SubscriptionRecoveryPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SubscriptionRecoveryStateProtocol
        var isErrorPresented: Bool = false
        var isNoActivePresented: Bool = false
        var input: String = ""

        init(
            state: any SubscriptionRecoveryStateProtocol,
            isErrorPresented: Bool = false,
            isNoActivePresented: Bool = false,
            input: String = "",
        ) {
            self.state = state
            self.isErrorPresented = isErrorPresented
            self.isNoActivePresented = isNoActivePresented
            self.input = input
        }

        var body: some View {
            SubscriptionRecoveryScreenView(
                viewModel: SubscriptionRecoveryPreviewFactory.makeViewModel(
                    container: container,
                    router: router,
                    state: state,
                    input: input,
                ),
            )
            .previewError(
                isPresented: isErrorPresented,
            )
            .previewMessage(
                type: .error,
                title: isNoActivePresented ? .subscriptionRecoveryNoActiveTitle : nil,
                description: isNoActivePresented ? .subscriptionRecoveryNoActiveDescription : nil,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
