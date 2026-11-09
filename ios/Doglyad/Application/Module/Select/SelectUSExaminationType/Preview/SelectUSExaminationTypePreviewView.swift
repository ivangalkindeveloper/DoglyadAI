#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectUSExaminationTypePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectUSExaminationTypeStateProtocol
        let isRecentSectionVisible: Bool

        init(
            state: any SelectUSExaminationTypeStateProtocol,
            isRecentSectionVisible: Bool = true,
        ) {
            self.state = state
            self.isRecentSectionVisible = isRecentSectionVisible
        }

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
                    currentValue: isRecentSectionVisible ? ModulePreviewFactory.examinationType : nil,
                    onSelected: { _ in },
                ),
            )

            model.recentTypeIds = isRecentSectionVisible
                ? [ModulePreviewFactory.examinationType.id] + Array(
                    container.usExaminationTypesById.keys.sorted().filter {
                        $0 != ModulePreviewFactory.examinationType.id
                    }.prefix(
                        USExaminationRecentTypes.maximumCount - 1,
                    ),
                )
                : []

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
