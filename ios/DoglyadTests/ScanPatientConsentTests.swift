import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ScanPatientConsentTests {
    @Test(
        arguments: [false, true],
    )
    func generationChecksPreferenceAndContinuesOnlyAfterConfirmation(
        isNeedPatientConsent: Bool,
    ) async throws {
        let repository = PatientConsentRepository(
            wrapped: DependencyContainer.previewable.userSettingsRepository,
        )
        repository.isNeedPatientConsent = isNeedPatientConsent
        let backend = SubscriptionTestBackendRepository()
        backend.isAccessAvailable = true
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            userSettingsRepository: repository,
            subscriptionBackendRepository: backend,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        var generations = 0
        let model = makeModel(
            container: container,
            router: router,
            onStart: { request in
                #expect(
                    request.examinationData.isPatientConsent,
                )
                generations += 1
                return ModulePreviewFactory.report
            },
        )
        model.onTapScan()
        await model.lastTask?.value
        if isNeedPatientConsent {
            #expect(
                router.sheet?.type == .patientConsent && generations == 0,
            )
            router.dismissSheet()
            #expect(
                generations == 0 && model.patientNameTextController.text == "Тестовый пациент",
            )
            model.onTapScan()
            await model.lastTask?.value
            let arguments = try #require(
                router.sheet?.arguments as? PatientConsentArguments,
            )
            router.dismissSheet()
            arguments.onConfirm()
        }
        // The subscription request and report creation are independently scheduled tasks.
        for _ in 0 ..< 1000 {
            await model.lastTask?.value
            if generations > 0 {
                break
            }
            await Task.yield()
        }
        #expect(
            generations == 1 && router.sheet?.type != .patientConsent,
        )
        #expect(
            repository.readCount == (isNeedPatientConsent ? 2 : 1),
        )
        model.onDisappear()
        model.stopDraftAutosave()
    }

    @Test
    func failedPreferenceReadPreservesFormAndDoesNotGenerate() async {
        let repository = PatientConsentRepository(
            wrapped: DependencyContainer.previewable.userSettingsRepository,
        )
        repository.onRead = {
            throw CocoaError(
                .fileReadUnknown,
            )
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            userSettingsRepository: repository,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
        }
        defer {
            observation.cancel()
        }
        var generations = 0
        let model = makeModel(
            container: container,
            router: router,
            messager: messager,
            onStart: { _ in
                generations += 1
                return ModulePreviewFactory.report
            },
        )
        model.onTapScan()
        await model.lastTask?.value
        #expect(
            generations == 0 && router.sheet == nil && errors == 1,
        )
        #expect(
            model.state is ScanInitialState && model.patientNameTextController.text == "Тестовый пациент",
        )
        model.onDisappear()
        model.stopDraftAutosave()
    }

    @Test
    func leavingScanDiscardsLatePreferenceRead() async {
        let repository = PatientConsentRepository(
            wrapped: DependencyContainer.previewable.userSettingsRepository,
        )
        var resume: CheckedContinuation<Bool, Never>?
        repository.onRead = {
            await withCheckedContinuation {
                resume = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            userSettingsRepository: repository,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        var generations = 0
        let model = makeModel(
            container: container,
            router: router,
            onStart: { _ in
                generations += 1
                return ModulePreviewFactory.report
            },
        )
        model.onTapScan()
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.onTapScan()
        #expect(
            repository.readCount == 1 && model.state is ScanInitialState,
        )
        model.onDisappear()
        resume?.resume(
            returning: true,
        )
        await task?.value
        #expect(
            router.sheet == nil && generations == 0,
        )
        model.stopDraftAutosave()
    }

    private func makeModel(
        container: DependencyContainer,
        router: DRouter,
        messager: DMessager = DMessager(),
        onStart: @escaping (USExaminationRequest) async throws -> USExaminationReport,
    ) -> ScanViewModel {
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
                nil
            },
            onTemplateSelected: { _ in },
            onTemplateReset: {},
            getNeuralModel: {
                container.usExaminationNeuralModelDefault
            },
            onNeuralModelSelected: { _ in },
            onStartReportGeneration: onStart,
        )
        model.examinationNumberTextController.setText(
            "Consent-001",
        )
        model.patientNameTextController.setText(
            "Тестовый пациент",
        )
        model.examinationDescriptionTextController.setText(
            "Тестовое описание исследования",
        )
        return model
    }
}
