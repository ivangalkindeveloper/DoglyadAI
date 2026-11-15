#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct SettingsAIPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any SettingsAIStateProtocol
        let transcriberType: TranscriberType?

        init(
            state: any SettingsAIStateProtocol,
            transcriberType: TranscriberType? = nil,
        ) {
            self.state = state
            self.transcriberType = transcriberType
        }

        var body: some View {
            let isErrorPresented = switch state {
            case _ as SettingsAIErrorState: true
            default: false
            }

            let model = SettingsAIViewModel(
                container: container,
                getInitialNeuralModel: {
                    container.usExaminationNeuralModelDefault
                },
                getInitialIsMarkdown: {
                    true
                },
                getInitialTemperature: {
                    0.2
                },
                getInitialMaxTokens: {
                    2048
                },
                messager: messager,
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
                onNeuralModelSelected: { _ in },
                onSettingsSaved: { _, _, _, _, _ in },
            )

            if let transcriberType {
                model.transcriberType = transcriberType
            }

            model.preparePreview(
                state: state,
            )
            return SettingsAIScreenView(
                viewModel: model,
            )
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
