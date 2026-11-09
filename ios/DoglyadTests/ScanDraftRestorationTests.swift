import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ScanDraftRestorationTests {
    @Test
    func delayedDraftMergesOnlyUntouchedValuesAndPersistsEarlyEdits() async throws {
        let repository = StateDraftRepository()
        let stored = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        repository.draft = stored
        var response: CheckedContinuation<USExaminationDraft?, Error>?
        repository.onRead = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let reports = StateReportRepository()
        let container = makeStateTestContainer(
            reportRepository: reports,
            draftRepository: repository,
        )
        try await reports.setSelectedExaminationTypeId(
            id: container.usExaminationTypeDefault.id,
        )
        let model = makeModel(
            container: container,
        )
        let patientNameTextController = model.patientNameTextController
        model.onAppear()
        let restoration = model.draftRestorationTask
        while response == nil {
            await Task.yield()
        }
        #expect(
            model.state is ScanInitialState,
        )
        model.patientNameTextController.setText(
            "Введённое имя",
        )
        model.patientNameTextController.clear()
        model.patientComplaintsTextController.setText(
            "Новые жалобы",
        )
        let date = Date(
            timeIntervalSince1970: 700000000,
        )
        model.patientDateOfBirth = date
        model.patientGender = .female
        let type = USExaminationType(
            id: "new-local-selection",
            title: "New selection",
            contextualStrings: [],
        )
        model.usExaminationType = type
        model.photos = Array(
            stored.photos.prefix(
                1,
            ),
        )
        model.onTapSettings()
        #expect(
            repository.savedForms.isEmpty && repository.savedPhotos.isEmpty,
        )
        response?.resume(
            returning: stored,
        )
        await restoration?.value
        try await model.waitForPendingDraftSave()
        #expect(
            model.patientNameTextController === patientNameTextController && model.patientNameTextController.text.isEmpty,
        )
        #expect(
            model.patientComplaintsTextController.text == "Новые жалобы",
        )
        #expect(
            model.patientGender == .female && model.patientDateOfBirth == date,
        )
        #expect(
            model.usExaminationType == type && model.photos == Array(
                stored.photos.prefix(
                    1,
                ),
            ),
        )
        #expect(
            model.patientHeightCMTextController.text == stored.form.patientHeightCM,
        )
        #expect(
            model.examinationDescriptionTextController.text == stored.form.examinationDescription,
        )
        #expect(
            repository.savedForms.last == model.makeDraftSnapshot(),
        )
        #expect(
            repository.savedPhotos.last == model.photos,
        )
        #expect(
            model.state is ScanInitialState,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func clearDuringReadRejectsALateDraft() async throws {
        let repository = StateDraftRepository()
        let stored = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        repository.draft = stored
        var response: CheckedContinuation<USExaminationDraft?, Error>?
        repository.onRead = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: repository,
        )
        let model = makeModel(
            container: container,
        )
        model.onAppear()
        let restoration = model.draftRestorationTask
        while response == nil {
            await Task.yield()
        }
        model.onTapClear()
        await model.lastTask?.value
        let cleared = model.makeDraftSnapshot()
        #expect(
            repository.clearCount == 1 && repository.draft == nil,
        )
        response?.resume(
            returning: stored,
        )
        await restoration?.value
        #expect(
            model.makeDraftSnapshot() == cleared && model.photos.isEmpty,
        )
        #expect(
            model.state is ScanInitialState,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func missingDraftKeepsEarlyEditsAndRestoresUntouchedDefaults() async throws {
        let repository = StateDraftRepository()
        var response: CheckedContinuation<USExaminationDraft?, Error>?
        repository.onRead = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: repository,
        )
        let model = makeModel(
            container: container,
        )
        model.onAppear()
        let restoration = model.draftRestorationTask
        while response == nil {
            await Task.yield()
        }
        model.examinationNumberTextController.setText(
            "Мой номер",
        )
        response?.resume(
            returning: nil,
        )
        await restoration?.value
        try await model.waitForPendingDraftSave()
        #expect(
            model.examinationNumberTextController.text == "Мой номер",
        )
        #expect(
            !model.patientNameTextController.text.isEmpty,
        )
        #expect(
            repository.savedForms.last == model.makeDraftSnapshot(),
        )
        #expect(
            model.state is ScanInitialState,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func submissionDuringReadInvalidatesRestorationBeforePreparingGeneration() async {
        let repository = StateDraftRepository()
        var response: CheckedContinuation<USExaminationDraft?, Error>?
        repository.onRead = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: repository,
        )
        let model = makeModel(
            container: container,
        )
        model.onAppear()
        let restoration = model.draftRestorationTask
        while response == nil {
            await Task.yield()
        }
        model.examinationNumberTextController.setText(
            "Новый номер",
        )
        model.patientNameTextController.setText(
            "Новый пациент",
        )
        model.examinationDescriptionTextController.setText(
            "Новое описание",
        )
        let edited = model.makeDraftSnapshot()
        model.onTapScan()
        let operation = model.lastTask
        #expect(
            operation != nil && model.draftRestorationTask == nil,
        )
        model.onDisappear()
        response?.resume(
            returning: USExaminationDraft(
                form: ModulePreviewFactory.draft,
                photos: ModulePreviewFactory.photos,
            ),
        )
        await restoration?.value
        await operation?.value
        #expect(
            model.makeDraftSnapshot() == edited && model.photos.isEmpty,
        )
        model.stopDraftAutosave()
    }

    @Test
    func backgroundSaveWaitsForRestorationAndPersistsEarlyInput() async {
        let repository = StateDraftRepository()
        let stored = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        repository.draft = stored
        var response: CheckedContinuation<USExaminationDraft?, Error>?
        repository.onRead = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: repository,
        )
        let model = makeModel(
            container: container,
        )
        model.onAppear()
        let restoration = model.draftRestorationTask
        while response == nil {
            await Task.yield()
        }
        model.patientNameTextController.setText(
            "Ввод перед фоном",
        )
        model.onBackground()
        let saving = model.lastTask
        #expect(
            saving != nil && repository.savedForms.isEmpty,
        )
        response?.resume(
            returning: stored,
        )
        await restoration?.value
        await saving?.value
        #expect(
            repository.savedForms.last?.patientName == "Ввод перед фоном",
        )
        #expect(
            repository.savedForms.last?.examinationDescription == stored.form.examinationDescription,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func selectedTypeReadFailureKeepsTheStoredDraftIntactUntilRetry() async throws {
        let repository = StateDraftRepository()
        let stored = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        repository.draft = stored
        let reports = StateReportRepository()
        reports.isSelectionReadFailed = true
        let container = makeStateTestContainer(
            reportRepository: reports,
            draftRepository: repository,
        )
        let model = makeModel(
            container: container,
        )
        model.onAppear()
        await model.draftRestorationTask?.value
        #expect(
            model.state is ScanInitializationErrorState,
        )
        #expect(
            model.patientNameTextController.text.isEmpty && model.photos.isEmpty,
        )
        #expect(
            repository.draft?.form == stored.form && repository.savedForms.isEmpty,
        )
        model.patientNameTextController.setText(
            "Новое имя после ошибки",
        )
        reports.isSelectionReadFailed = false
        model.onResume()
        await model.draftRestorationTask?.value
        try await model.waitForPendingDraftSave()
        #expect(
            model.patientNameTextController.text == "Новое имя после ошибки",
        )
        #expect(
            model.examinationDescriptionTextController.text == stored.form.examinationDescription,
        )
        #expect(
            model.photos == stored.photos && model.state is ScanInitialState,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func localClearKeepsNewEditsAndClearsUntouchedFieldsWithoutLoading() async throws {
        let repository = StateDraftRepository()
        repository.draft = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        let model = makeModel(
            container: makeStateTestContainer(
                reportRepository: StateReportRepository(),
                draftRepository: repository,
            ),
        )
        model.onAppear()
        await model.draftRestorationTask?.value
        let initial = model.state
        var resume: CheckedContinuation<Void, Never>?
        repository.onClear = {
            await withCheckedContinuation {
                resume = $0
            }
        }
        model.onTapClear()
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        #expect(
            model.state === initial,
        )
        model.patientNameTextController.setText(
            "Entered while clearing",
        )
        model.patientComplaintsTextController.setText(
            "typed then cleared",
        )
        model.patientComplaintsTextController.setText(
            "",
        )
        resume?.resume()
        await task?.value
        try await model.waitForPendingDraftSave()
        #expect(
            model.state is ScanInitialState && repository.clearCount == 1,
        )
        #expect(
            model.patientNameTextController.text == "Entered while clearing",
        )
        #expect(
            model.patientComplaintsTextController.text.isEmpty && model.examinationDescriptionTextController.text.isEmpty,
        )
        #expect(
            model.photos.isEmpty && repository.draft?.form.patientName == "Entered while clearing",
        )
        #expect(
            repository.draft?.form.examinationDescription.isEmpty == true,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    @Test
    func backgroundSaveWaitsForAnInteractiveLocalClear() async throws {
        let repository = StateDraftRepository()
        repository.draft = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        let model = makeModel(
            container: makeStateTestContainer(
                reportRepository: StateReportRepository(),
                draftRepository: repository,
            ),
        )
        model.onAppear()
        await model.draftRestorationTask?.value
        var resume: CheckedContinuation<Void, Never>?
        repository.onClear = {
            await withCheckedContinuation {
                resume = $0
            }
        }
        model.onTapClear()
        while resume == nil {
            await Task.yield()
        }
        model.patientNameTextController.setText(
            "Saved before background completion",
        )
        model.onBackground()
        let background = model.lastTask
        resume?.resume()
        await background?.value
        #expect(
            repository.draft?.form.patientName == "Saved before background completion",
        )
        #expect(
            repository.draft?.form.examinationDescription.isEmpty == true,
        )
        model.stopDraftAutosave()
        model.onDisappear()
    }

    private func makeModel(
        container: DependencyContainer,
    ) -> ScanViewModel {
        ScanViewModel(
            container: container,
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
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
            onStartReportGeneration: { _ in
                ModulePreviewFactory.report
            },
        )
    }
}
