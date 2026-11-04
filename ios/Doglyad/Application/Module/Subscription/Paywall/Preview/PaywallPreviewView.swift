#if DEBUG
    import Router
    import SwiftUI

    struct PaywallPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        var state: (any PaywallStateProtocol)?

        var body: some View {
            let model = PaywallPreviewFactory.makeViewModel(
                container: container,
                router: router,
            )

            if let state {
                model.preparePreview(
                    state: state,
                )
            }
            return PaywallScreenView(
                viewModel: model,
            )
            .id(
                state.map {
                    ObjectIdentifier(
                        $0,
                    )
                },
            ).allowsHitTesting(
                state == nil,
            )
        }
    }
#endif
