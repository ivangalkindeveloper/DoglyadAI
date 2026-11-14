#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct WebDocumentPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any WebDocumentStateProtocol
        var document: WebDocumentPreviewDocument = .privacyPolicy

        init(
            state: any WebDocumentStateProtocol,
            document: WebDocumentPreviewDocument = .privacyPolicy,
        ) {
            self.state = state
            self.document = document
        }

        var body: some View {
            let isErrorPresented = switch state {
            case _ as WebDocumentErrorState: true
            default: false
            }

            let model = WebDocumentViewModel(
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
                arguments: document.arguments(
                    container: container,
                ),
            )

            model.previewHTML = document.html

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                WebDocumentBottomSheetView(
                    viewModel: model,
                )
            }
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
