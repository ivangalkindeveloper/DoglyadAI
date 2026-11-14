#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SelectTranscriptParserPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let state: any SelectTranscriptParserStateProtocol

        init(
            state: any SelectTranscriptParserStateProtocol,
        ) {
            self.state = state
        }

        var body: some View {
            let model = SelectTranscriptParserViewModel(
                container: container,
                router: router,
                arguments: SelectTranscriptParserArguments(
                    currentValue: .server,
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
                SelectTranscriptParserBottomSheetView(
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
