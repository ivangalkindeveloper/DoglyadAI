#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectTemplatePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectTemplateStateProtocol
        let templates: [USExaminationTemplate]

        init(
            state: any SelectTemplateStateProtocol,
            templates: [USExaminationTemplate],
        ) {
            self.state = state
            self.templates = templates
        }

        var body: some View {
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
                    templates: templates,
                    currentValue: templates.first,
                    onSelected: { _ in },
                ),
            )

            model.setPreviewTemplates(
                templates,
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SelectTemplateBottomSheetView(
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
