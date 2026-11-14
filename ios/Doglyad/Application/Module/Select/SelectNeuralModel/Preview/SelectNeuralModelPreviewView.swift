#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectNeuralModelPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectNeuralModelStateProtocol

        init(
            state: any SelectNeuralModelStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = SelectNeuralModelViewModel(
                container: container,
                router: router,
                arguments: SelectNeuralModelArguments(
                    currentValue: container.usExaminationNeuralModelDefault,
                    onSelected: { _ in },
                ),
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
            )

            model.preparePreview(
                state: state,
            )
            return ModuleBottomSheetPreviewView {
                SelectNeuralModelBottomSheetView(
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
