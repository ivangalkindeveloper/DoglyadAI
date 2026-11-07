#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectTemplatePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectTemplateStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as SelectTemplateFailedState: true
            default: false
            }

            let model = SelectTemplateViewModel(
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
                arguments: SelectTemplateArguments(
                    currentValue: ModulePreviewFactory.template,
                    onSelected: { _ in },
                ),
            )

            model.setPreviewTemplates(
                [ModulePreviewFactory.template],
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SelectTemplateBottomSheetView(
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
