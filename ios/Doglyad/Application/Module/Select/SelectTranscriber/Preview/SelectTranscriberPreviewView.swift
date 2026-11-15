#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectTranscriberPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectTranscriberStateProtocol

        init(
            state: any SelectTranscriberStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = SelectTranscriberViewModel(
                container: container,
                router: router,
                arguments: SelectTranscriberArguments(
                    currentValue: .speechAnalyzer,
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
                state: state.copyWith(
                    options: [.speechAnalyzer, .whisperKit, .tOne],
                ),
            )
            return ModuleBottomSheetPreviewView {
                SelectTranscriberBottomSheetView(
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
