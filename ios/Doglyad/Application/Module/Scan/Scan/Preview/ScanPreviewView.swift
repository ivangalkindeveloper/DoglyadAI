#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct ScanPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any ScanStateProtocol

        var body: some View {
            let isErrorPresented = switch state {
            case _ as ScanInitializationFailedState, _ as ScanFailedState: true
            default: false
            }

            let model = ScanViewModel(
                container: container,
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
                observeExaminationChanges: { _ in
                    AnyCancellable {}
                },
                getSelectedTemplate: {
                    ModulePreviewFactory.template
                },
                onTemplateSelected: { _ in },
                onTemplateReset: {},
                getNeuralModel: {
                    container.usExaminationNeuralModelDefault
                },
                onNeuralModelSelected: { _ in },
                onStartReportGeneration: { _ in
                    ModulePreviewFactory.report
                },
            )

            model.patientNameTextController.setText(
                "Тестовый пациент",
            )

            model.examinationDescriptionTextController.setText(
                USExaminationReportPreviewFactory.description,
            )

            model.photos = ModulePreviewFactory.photos

            model.preparePreview(
                state: state,
            )
            return ScanScreenView(
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
