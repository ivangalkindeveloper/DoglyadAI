#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct TemplateDeletePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any TemplateDeleteStateProtocol

        init(
            state: any TemplateDeleteStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = TemplateDeleteViewModel(
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
                arguments: TemplateDeleteArguments(
                    onConfirm: {},
                ),
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                TemplateDeleteBottomSheetView(
                    viewModel: model,
                )
            }
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }
#endif
