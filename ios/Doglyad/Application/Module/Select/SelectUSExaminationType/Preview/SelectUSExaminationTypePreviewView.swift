#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectUSExaminationTypePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectUSExaminationTypeStateProtocol

        var body: some View {
            let model = SelectUSExaminationTypeViewModel(
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
                arguments: SelectUSExaminationTypeArguments(
                    currentValue: ModulePreviewFactory.examinationType,
                    onSelected: { _ in },
                ),
            )

            model.recentTypeIds = [ModulePreviewFactory.examinationType.id]

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SelectUSExaminationTypeBottomSheetView(
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
