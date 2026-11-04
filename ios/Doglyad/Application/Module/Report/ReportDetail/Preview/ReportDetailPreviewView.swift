#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    struct ReportDetailPreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        @EnvironmentObject private var messager: DMessager
        let state: any ReportDetailStateProtocol

        var body: some View {
            let model = ReportDetailViewModel(
                container: container,
                messager: messager,
                router: router,
                initialReport: ModulePreviewFactory.report,
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
                getNeuralModel: {
                    container.usExaminationNeuralModelDefault
                },
                onNeuralModelSelected: { _ in },
                currentReport: {
                    $0
                },
                observeReports: { _ in
                    AnyCancellable {}
                },
                onStartReportGeneration: { _, _ in
                    ModulePreviewFactory.report
                },
            )

            model.preparePreview(
                state: state,
            )
            return ReportDetailScreenView(
                viewModel: model,
            )
            .id(
                ObjectIdentifier(
                    state,
                ),
            )
        }
    }

    struct ReportDetailExpandableTextPreviewView: DViewProtocol {
        @EnvironmentObject var theme: DTheme

        private let fixture: ExpandableContentPreviewFixture
        let scenario: ExpandableContentPreviewFixture.Scenario

        init(
            scenario: ExpandableContentPreviewFixture.Scenario,
        ) {
            fixture = ExpandableContentPreviewFixture(
                scenario: scenario,
            )
            self.scenario = scenario
        }

        var body: some View {
            ReportDetailExpandableTextView(
                text: fixture.text,
                backgroundColor: color.grayscaleBackgroundWeak,
                collapsedLineLimit: fixture.collapsedLineLimit,
            )
            .id(
                scenario,
            )
            .padding(
                size.s16,
            )
            .frame(
                width: fixture.width,
                alignment: .leading,
            )
            .background {
                DCardBackground(
                    cornerRadius: size.s16,
                    color: color.grayscaleBackgroundWeak,
                )
            }
            .padding(
                size.s16,
            )
        }
    }
#endif
