import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing
import UIKit

@MainActor
struct ContentDesignTests {
    @Test
    func unavailableHistoryCountKeepsSettingsNavigationWithoutAnError() async {
        let repository = StateReportRepository()
        repository.isReportCountReadFailed = true
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
        }
        defer {
            observation.cancel()
        }
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let model = MenuViewModel(
            messager: messager,
            container: container,
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
        )
        #expect(
            model.state is MenuContentState && model.reportsCount == nil,
        )
        model.onAppear()
        model.onTapHistory()
        await model.lastTask?.value
        #expect(
            model.state is MenuContentState && model.reportsCount == nil && errors == 0,
        )
        #expect(
            model.historyDescription == container.l10n[
                .menuHistoryPurposeDescription,
            ],
        )
        #expect(
            router.path.count == 1,
        )
        model.onDisappear()
    }

    @Test
    func templateInitializationRetryMergesLoadedDataWithoutReplacingEdits() async throws {
        let repository = DesignTemplateRepository(
            template: ModulePreviewFactory.template,
        )
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            templateRepository: repository,
        )
        let messager = DMessager()
        var errorCount = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errorCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = TemplateEditViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
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
            messager: messager,
            arguments: TemplateEditArguments(
                templateId: repository.template.id,
            ),
            onSaveTemplate: { _ in },
            onDeleteTemplate: { _ in },
        )
        let nameController = model.nameTextController
        let contentController = model.templateTextController
        model.onAppear()
        await model.lastTask?.value
        #expect(
            model.state is TemplateEditInitializationErrorState,
        )
        #expect(
            errorCount == 1,
        )
        model.nameTextController.setText(
            "Имя после ошибки",
        )
        repository.isReadFailed = false
        model.onTapRetryInitialization()
        await model.lastTask?.value
        #expect(
            model.state is TemplateEditInitialState,
        )
        #expect(
            model.nameTextController === nameController,
        )
        #expect(
            model.templateTextController === contentController,
        )
        #expect(
            model.nameTextController.text == "Имя после ошибки",
        )
        #expect(
            model.templateTextController.text == repository.template.content,
        )
        #expect(
            errorCount == 1,
        )
        model.onDisappear()
    }

    @Test
    func scanInitializationRetryPreservesEditsAndRestoresUntouchedDraftFields() async throws {
        let draft = StateDraftRepository()
        draft.isReadFailed = true
        draft.draft = USExaminationDraft(
            form: ModulePreviewFactory.draft,
            photos: ModulePreviewFactory.photos,
        )
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: draft,
        )
        let messager = DMessager()
        var errorCount = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errorCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = ScanViewModel(
            container: container,
            messager: messager,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
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
                throw CancellationError()
            },
        )
        let patientController = model.patientNameTextController
        model.onAppear()
        await model.draftRestorationTask?.value
        #expect(
            model.state is ScanInitializationErrorState,
        )
        #expect(
            errorCount == 1,
        )
        model.patientNameTextController.setText(
            "Новое имя после ошибки",
        )
        draft.isReadFailed = false
        model.onResume()
        await model.draftRestorationTask?.value
        #expect(
            model.state is ScanInitialState,
        )
        #expect(
            model.patientNameTextController === patientController,
        )
        #expect(
            model.patientNameTextController.text == "Новое имя после ошибки",
        )
        #expect(
            model.examinationDescriptionTextController.text == ModulePreviewFactory.draft.examinationDescription,
        )
        #expect(
            model.photos == ModulePreviewFactory.photos,
        )
        model.onDisappear()
    }

    @Test
    func historyPaginationFailureRetainsItemsAndRetriesTheSameOffset() async throws {
        let repository = StateReportRepository()
        repository.isSaveFailed = false
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        for _ in 0 ..< container.applicationConfig.history.pageSize + 1 {
            var report = ModulePreviewFactory.report
            report.id = UUID()
            try await repository.setReport(
                report: report,
            )
        }
        let messager = DMessager()
        var errorCount = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errorCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = HistoryViewModel(
            messager: messager,
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
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
            currentReport: {
                $0
            },
            observeReports: { _ in
                AnyCancellable {}
            },
        )
        model.onAppear()
        await model.lastTask?.value
        let initialIDs = model.sections.flatMap(
            \.reports,
        ).map(
            \.id,
        )
        let offset = try #require(
            model.nextOffset,
        )
        repository.failedReportsOffset = offset
        model.onOffsetAppear()
        await model.lastTask?.value
        #expect(
            model.state is HistoryErrorState,
        )
        #expect(
            model.sections.flatMap(
                \.reports,
            ).map(
                \.id,
            ) == initialIDs,
        )
        #expect(
            model.nextOffset == offset,
        )
        #expect(
            errorCount == 1,
        )
        repository.failedReportsOffset = nil
        model.onOffsetAppear()
        await model.lastTask?.value
        #expect(
            model.state is HistoryContentState,
        )
        #expect(
            model.sections.flatMap(
                \.reports,
            ).count == initialIDs.count + 1,
        )
        #expect(
            model.nextOffset == nil,
        )
        #expect(
            errorCount == 1,
        )
        model.onDisappear()
    }

    @Test(
        arguments: [true, false],
    )
    func photoImportPreservesAvailableImagesAndReportsOnlyFailures(
        isSomeImagesUnavailable: Bool,
    ) {
        let container = ModulePreviewFactory.makeContainer()
        let messager = DMessager()
        var errorCount = 0
        var receivedImages: [UIImage] = []
        let observation = messager.$message.dropFirst().sink { _ in
            errorCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = PhotoLibraryPickerViewModel(
            messager: messager,
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
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
            arguments: PhotoLibraryPickerArguments(
                selectionLimit: 3,
                onComplete: {
                    receivedImages = $0
                },
            ),
        )
        let image = UIImage()
        model.onComplete(
            [image],
            isSomeImagesUnavailable: isSomeImagesUnavailable,
        )
        #expect(
            receivedImages.count == 1 && receivedImages[
                0,
            ] === image,
        )
        #expect(
            errorCount == (isSomeImagesUnavailable ? 1 : 0),
        )
    }

    @Test
    func failedSpeechPreviewConstructionHasNoErrorMessageOrStartupSideEffects() {
        let container = ModulePreviewFactory.makeContainer()
        let messager = DMessager()
        var messageCount = 0
        let observation = messager.$message.dropFirst().sink { _ in
            messageCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = ScanSpeechTranscriptPreviewFixture(
            scenario: .failed,
        ).makeViewModel(
            container: container,
            messager: messager,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
        )
        #expect(
            model.isPreviewSnapshot,
        )
        #expect(
            model.state is ScanSpeechReviewTranscriptState,
        )
        #expect(
            model.transcriptTextController.text.isEmpty,
        )
        #expect(
            model.lastTask == nil,
        )
        #expect(
            messageCount == 0,
        )
    }
}
