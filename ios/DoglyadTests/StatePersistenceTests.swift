import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct StatePersistenceTests {
    @Test
    func retryingReportSaveRetainsCandidateAndClearsOnlyAfterPersistence() async {
        let reports = StateReportRepository()
        let drafts = StateDraftRepository()
        let container = makeStateTestContainer(
            reportRepository: reports,
            draftRepository: drafts,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        var requestCountUpdates = 0
        let model = ScanViewModel(
            container: container,
            messager: DMessager(),
            router: router,
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: { requestCountUpdates += 1 },
            observeExaminationChanges: { _ in AnyCancellable {} },
            getSelectedTemplate: { nil },
            onTemplateSelected: { _ in },
            onTemplateReset: {},
            getNeuralModel: { container.usExaminationNeuralModelDefault },
            onNeuralModelSelected: { _ in },
        )
        let form = model
        let examinationTextController = model.examinationDescriptionTextController
        form.examinationNumberTextController.setText(
            "12",
        )
        form.patientNameTextController.setText(
            "Patient",
        )
        form.examinationDescriptionTextController.setText(
            "Original examination",
        )
        let snapshot = model.makeDraftSnapshot()
        let patientNameTextController = model.patientNameTextController
        patientNameTextController.setText(
            "Changed name",
        )
        model.applyDraft(
            USExaminationDraft(
                form: snapshot,
                photos: [],
            ),
        )
        #expect(
            model.makeDraftSnapshot() == snapshot,
        )
        #expect(
            model.patientNameTextController === patientNameTextController,
        )
        let report = USExaminationReport(
            date: Date(),
            neuralModelSettings: container.initialNeuralModelSettings,
            examinationData: USExaminationData(
                usExaminationTypeId: form.usExaminationType.id,
                photos: [],
                examinationNumber: "12",
                patientName: "Patient",
                patientGender: form.patientGender,
                patientDateOfBirth: form.patientDateOfBirth,
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Original examination",
            ),
            actualModelReport: USExaminationModelReport(
                date: Date(),
                modelId: "test",
                description: "Generated description",
                conclusion: "Generated conclusion",
                recommendations: nil,
            ),
            previousModelReports: [],
        )
        model.emit(
            ScanSaveFailedState(
                report: report,
                snapshot: snapshot,
                error: CocoaError(
                    .fileWriteUnknown,
                ),
            ),
        )

        model.onTapScan()
        await model.lastTask?.value
        switch model.state {
        case let state as ScanSaveFailedState:
            #expect(
                state.report.id == report.id,
            )
            #expect(
                state.snapshot == snapshot,
            )
            #expect(
                model.examinationDescriptionTextController === examinationTextController,
            )
        default: Issue.record(
                "A failed save must retain the generated report",
            )
        }
        #expect(
            form.examinationDescriptionTextController.text == "Original examination",
        )
        #expect(
            drafts.clearCount == 0,
        )
        #expect(
            router.sheet == nil,
        )
        #expect(
            requestCountUpdates == 0,
        )

        reports.isSaveFailed = false
        model.onTapScan()
        await model.lastTask?.value
        switch model.state {
        case _ as ScanDefaultState: break
        default: Issue.record(
                "A successful save must return to the examination form",
            )
        }
        #expect(
            reports.generationCount == 0,
        )
        #expect(
            reports.saveCount == 2,
        )
        #expect(
            reports.reports.map(
                \.id,
            ) == [report.id],
        )
        #expect(
            drafts.clearCount == 1,
        )
        #expect(
            requestCountUpdates == 1,
        )
        #expect(
            form.examinationDescriptionTextController.text.isEmpty,
        )
        #expect(
            router.sheet?.type == .reportReceived,
        )
        model.stopDraftAutosave()
    }

    @Test
    func failedSettingsSaveRetainsEditedDataAndControllers() async {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .userSettings,
            ),
        )
        let model = UserSettingsViewModel(
            container: container,
            messager: DMessager(),
            router: router,
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            getInitialEmail: { nil },
            getInitialIsRecommendationsIncluded: { false },
            getInitialIsPhotoRemarks: { false },
            getInitialIsDescriptionRemarks: { false },
            onSaved: { _, _, _, _ in throw CocoaError(
                .fileWriteUnknown,
            ) },
        )
        let form = model
        let emailTextController = model.emailTextController
        form.emailTextController.setText(
            "doctor@example.com",
        )
        model.togglePhotoRemarks()
        model.onTapSave()
        await model.lastTask?.value
        switch model.state {
        case _ as UserSettingsFailedState:
            #expect(
                model.emailTextController === emailTextController,
            )
            #expect(
                model.emailTextController.text == "doctor@example.com",
            )
            #expect(
                model.isPhotoRemarks,
            )
        default: Issue.record(
                "A failed settings save must retain the form",
            )
        }
        #expect(
            model.router.path.count == 1,
        )
    }
}
