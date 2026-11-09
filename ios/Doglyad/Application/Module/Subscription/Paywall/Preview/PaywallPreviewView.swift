#if DEBUG
    import Router
    import SwiftUI

    struct PaywallPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any PaywallStateProtocol

        var body: some View {
            let errorDescription: String? = switch state {
            case let error as PaywallCatalogErrorState: error.errorDescription
            case let error as PaywallOperationErrorState: error.errorDescription
            default: nil
            }

            let model = PaywallPreviewFactory.makeViewModel(
                container: container,
                router: router,
            )

            model.preparePreview(
                state: state,
            )
            return PaywallScreenView(
                viewModel: model,
            )
            .previewError(
                isPresented: errorDescription != nil,
                description: errorDescription,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
