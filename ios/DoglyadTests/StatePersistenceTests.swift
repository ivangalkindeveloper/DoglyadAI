import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct StatePersistenceTests {
    @Test
    func failedHistoryUpdateRetainsResultAndRetriesWithoutNewGeneration() async throws {
        let repository = StateReportRepository()
        repository.isSaveFailed = false
        repository.isGeneratedSaveFailed = true
        let controller = ReportGenerationController(
            repository: repository,
            photoOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 1024,
                compressionQuality: 0.8,
            ),
        )
        let request = USExaminationRequest(
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
                isPatientPreparedForExamination: true,
                isPatientConsent: true,
            ),
            template: nil,
            isRecommendationsIncluded: false,
            isPhotoRemarks: false,
            isDescriptionRemarks: false,
        )
        let report = try await controller.start(
            request: request,
            replacing: nil,
        )
        for _ in 0 ..< 100 {
            if repository.saveCount > 1 {
                break
            }
            await Task.yield()
        }
        #expect(
            repository.saveCount == 2,
        )
        let completed = controller.current(
            report,
        )
        #expect(
            completed.actualModelReport.generation.status == .completed,
        )
        #expect(
            completed.actualModelReport.description == "Synthetic result",
        )
        #expect(
            repository.reports.first?.actualModelReport.generation.status == .generating,
        )
        #expect(
            repository.generationCount == 1,
        )

        repository.isGeneratedSaveFailed = false
        for _ in 0 ..< 150 {
            if repository.reports.first?.actualModelReport.generation.status == .completed {
                break
            }
            try await Task.sleep(
                for: .milliseconds(
                    25,
                ),
            )
        }
        #expect(
            repository.reports.count == 1,
        )
        #expect(
            repository.reports.first == completed,
        )
        #expect(
            controller.current(
                report,
            ) == completed,
        )
        #expect(
            repository.generationCount == 1,
        )
    }

    @Test
    func generationStartsOnlyAfterHistorySaveAndDoesNotDuplicateEntry() async throws {
        let repository = StateReportRepository()
        let controller = ReportGenerationController(
            repository: repository,
            photoOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 1024,
                compressionQuality: 0.8,
            ),
        )
        let request = USExaminationRequest(
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
                isPatientPreparedForExamination: true,
                isPatientConsent: true,
            ),
            template: nil,
            isRecommendationsIncluded: false,
            isPhotoRemarks: false,
            isDescriptionRemarks: false,
        )
        do {
            _ = try await controller.start(
                request: request,
                replacing: nil,
            )
            Issue.record(
                "Initial persistence must succeed before generation",
            )
        } catch {}
        #expect(
            repository.generationCount == 0,
        )
        #expect(
            repository.reports.isEmpty,
        )
        repository.isSaveFailed = false
        let report = try await controller.start(
            request: request,
            replacing: nil,
        )
        #expect(
            repository.reports.count == 1,
        )
        #expect(
            repository.reports.first?.id == report.id,
        )
        #expect(
            repository.reports.first?.examinationData.isPatientConsent == true,
        )
        let encodedRequest = try #require(
            report.actualModelReport.generation.requestData,
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sentRequest = try decoder.decode(
            USReportGenerationRequest.self,
            from: encodedRequest,
        )
        #expect(
            sentRequest.examination.examinationData.isPatientConsent,
        )
        #expect(
            report.actualModelReport.generation.status == .generating,
        )
        #expect(
            report.actualModelReport.generation.requestData != nil,
        )
        for _ in 0 ..< 100 {
            if controller.current(
                report,
            ).actualModelReport.generation.status == .completed {
                break
            }
            await Task.yield()
        }
        #expect(
            controller.current(
                report,
            ).actualModelReport.generation.status == .completed,
        )
        #expect(
            repository.generationCount == 1,
        )
        #expect(
            repository.reports.count == 1,
        )
    }

    @Test
    func disconnectedStreamRecoversSameTaskAfterScreenObserverLeaves() async throws {
        let repository = StateReportRepository()
        repository.isSaveFailed = false
        repository.isServerGenerating = true
        let controller = ReportGenerationController(
            repository: repository,
            photoOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 1024,
                compressionQuality: 0.8,
            ),
        )
        let request = USExaminationRequest(
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
                isPatientPreparedForExamination: true,
                isPatientConsent: true,
            ),
            template: nil,
            isRecommendationsIncluded: false,
            isPhotoRemarks: false,
            isDescriptionRemarks: false,
        )
        let report = try await controller.start(
            request: request,
            replacing: nil,
        )
        for _ in 0 ..< 100 {
            if repository.eventContinuation != nil {
                break
            }
            await Task.yield()
        }
        let observer = controller.observe { _ in }
        observer.cancel()
        #expect(
            controller.current(
                report,
            ).actualModelReport.generation.status == .generating,
        )
        repository.isServerGenerating = false
        repository.eventContinuation?.finish(
            throwing: URLError(
                .networkConnectionLost,
            ),
        )
        for _ in 0 ..< 100 {
            if controller.current(
                report,
            ).actualModelReport.generation.status == .completed {
                break
            }
            try await Task.sleep(
                for: .milliseconds(
                    25,
                ),
            )
        }
        let recovered = controller.current(
            report,
        )
        #expect(
            recovered.actualModelReport.generation.status == .completed,
        )
        #expect(
            recovered.actualModelReport.generation.id == report.actualModelReport.generation.id,
        )
        #expect(
            repository.reports.count == 1,
        )
        #expect(
            repository.generationCount == 2,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func backgroundSuspendsStreamWithoutInterruptionAndResumesSameTask(
        isImmediateReturn: Bool,
    ) async throws {
        let repository = StateReportRepository()
        repository.isSaveFailed = false
        repository.isServerGenerating = true
        let controller = ReportGenerationController(
            repository: repository,
            photoOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 1024,
                compressionQuality: 0.8,
            ),
        )
        let request = USExaminationRequest(
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
                isPatientPreparedForExamination: true,
                isPatientConsent: true,
            ),
            template: nil,
            isRecommendationsIncluded: false,
            isPhotoRemarks: false,
            isDescriptionRemarks: false,
        )
        let report = try await controller.start(
            request: request,
            replacing: nil,
        )
        for _ in 0 ..< 100 {
            if repository.eventContinuation != nil {
                break
            }
            await Task.yield()
        }
        controller.setInBackground(
            true,
        )
        if !isImmediateReturn {
            for _ in 0 ..< 50 {
                await Task.yield()
            }
        }
        #expect(
            controller.current(
                report,
            ).actualModelReport.generation.status == .generating,
        )
        #expect(
            repository.reports.first?.actualModelReport.generation.status == .generating,
        )
        #expect(
            repository.generationCount == 1,
        )
        repository.isServerGenerating = false
        controller.setInBackground(
            false,
        )
        for _ in 0 ..< 100 {
            if controller.current(
                report,
            ).actualModelReport.generation.status == .completed {
                break
            }
            try await Task.sleep(
                for: .milliseconds(
                    25,
                ),
            )
        }
        let recovered = controller.current(
            report,
        )
        #expect(
            recovered.actualModelReport.generation.status == .completed,
        )
        #expect(
            recovered.actualModelReport.generation.id == report.actualModelReport.generation.id,
        )
        #expect(
            repository.reports.count == 1,
        )
        #expect(
            repository.generationCount == 2,
        )
    }

    @Test
    func newProcessMarksPendingHistoryInterruptedWithoutNetwork() async throws {
        let repository = StateReportRepository()
        repository.isSaveFailed = false
        repository.isServerGenerating = true
        let controller = ReportGenerationController(
            repository: repository,
            photoOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 1024,
                compressionQuality: 0.8,
            ),
        )
        let request = USExaminationRequest(
            settingsAI: SettingsAI(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "bladder",
                photos: [],
                examinationNumber: "1",
                patientName: "Synthetic",
                patientGender: .female,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Synthetic",
                isPatientPreparedForExamination: true,
                isPatientConsent: true,
            ),
            template: nil,
            isRecommendationsIncluded: false,
            isPhotoRemarks: false,
            isDescriptionRemarks: false,
        )
        let report = try await controller.start(
            request: request,
            replacing: nil,
        )
        for _ in 0 ..< 100 {
            if repository.eventContinuation != nil {
                break
            }
            await Task.yield()
        }
        controller.setInBackground(
            true,
        )
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            controller.current(
                report,
            ).actualModelReport.generation.status == .generating,
        )
        #expect(
            repository.reports.first?.actualModelReport.generation.status == .generating,
        )
        #expect(
            repository.generationCount == 1,
        )
        let requestsBeforeRestart = repository.generationCount
        try await repository.interruptPendingGenerations()
        let saved = try #require(
            repository.reports.first,
        )
        #expect(
            saved.actualModelReport.generation.status == .interrupted,
        )
        #expect(
            saved.actualModelReport.generation.id == report.actualModelReport.generation.id,
        )
        #expect(
            repository.generationCount == requestsBeforeRestart,
        )
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
                type: .workSettings,
            ),
        )
        let model = WorkSettingsViewModel(
            container: container,
            messager: DMessager(),
            router: router,
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
            getInitialEmail: {
                nil
            },
            getInitialIsNeedPatientConsent: {
                true
            },
            getInitialIsRecommendationsIncluded: {
                false
            },
            getInitialIsPhotoRemarks: {
                false
            },
            getInitialIsDescriptionRemarks: {
                false
            },
            onSaved: { _, _, _, _, _ in
                throw CocoaError(
                    .fileWriteUnknown,
                )
            },
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
        case _ as WorkSettingsErrorState:
            #expect(
                model.emailTextController === emailTextController,
            )
            #expect(
                model.emailTextController.text == "doctor@example.com",
            )
            #expect(
                model.isPhotoRemarks,
            )
        default:
            Issue.record(
                "A failed settings save must retain the form",
            )
        }
        #expect(
            model.router.path.count == 1,
        )
    }
}
