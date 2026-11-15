import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ReportReceivedObservationTests {
    init() {}

    @Test
    func reportUpdatesReuseTheContentPhaseAndStopAfterLeaving() {
        let container = DependencyContainer.previewable
        let initial = USExaminationReportPreviewFactory.makeReport(
            modelReport: USExaminationModelReport(
                date: Date(),
                modelId: "test",
                description: "",
                conclusion: "",
                recommendations: nil,
                generation: USReportGeneration(
                    status: .generating,
                ),
            ),
        )
        var current = initial
        let changes = PassthroughSubject<USExaminationReport, Never>()
        var observations = 0
        let model = ReportReceivedViewModel(
            container: container,
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            arguments: ReportReceivedArguments(
                report: initial,
            ),
            getSubscriptionStatus: {
                nil
            },
            observeSubscriptionStatus: { _ in
                AnyCancellable {}
            },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: {
                container.initialSettingsAI
            },
            onRefreshSubscriptionStatus: {},
            getUserEmail: {
                nil
            },
            currentReport: { _ in
                current
            },
            observeReports: { observer in
                observations += 1
                return changes.sink(
                    receiveValue: observer,
                )
            },
            retryGeneration: {
                $0
            },
        )
        model.onAppear()
        let initialState = model.state
        current = initial.replacingModelReport(
            USExaminationModelReport(
                date: initial.date,
                modelId: "test",
                description: "Completed report",
                conclusion: "Completed conclusion",
                recommendations: nil,
            ),
        )
        changes.send(
            current,
        )
        #expect(
            model.isCompleted,
        )
        #expect(
            model.report == current,
        )
        #expect(
            model.state !== initialState,
        )
        #expect(
            initialState.report == initial,
        )

        model.onDisappear()
        current = initial
        changes.send(
            initial,
        )
        #expect(
            model.isCompleted,
        )
        model.onAppear()
        model.onAppear()
        #expect(
            observations == 2,
        )
        #expect(
            !model.isCompleted,
        )
        current = initial.replacingModelReport(
            USExaminationModelReport(
                date: initial.date,
                modelId: "test",
                description: "Completed after returning",
                conclusion: "Completed conclusion",
                recommendations: nil,
            ),
        )
        changes.send(
            current,
        )
        #expect(
            model.isCompleted,
        )
        #expect(
            model.report == current,
        )
        model.onDisappear()
    }
}
