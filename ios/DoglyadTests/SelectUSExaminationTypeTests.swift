import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct SelectUSExaminationTypeTests {
    init() {}

    @Test
    func selectedTypeAppearsInRecentSectionAfterReopening() async throws {
        let repository = StateReportRepository()
        let type = USExaminationType(
            id: "thyroidGland",
            title: "Thyroid",
            contextualStrings: [],
        )
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
            usExaminationTypesById: [type.id: type],
        )
        let first = makeViewModel(
            container: container,
        )
        first.onAppear()
        await first.recentTypesReadTask?.value
        #expect(
            first.state is SelectUSExaminationTypeContentState,
        )
        #expect(
            first.sections.allSatisfy {
                $0.id != "recent"
            },
        )

        first.onTypeTap(
            type,
        )
        await first.lastTask?.value
        await first.recentTypeRecordTask?.value
        #expect(
            repository.recentExaminationTypeIds == [type.id],
        )
        first.onDisappear()

        let reopened = makeViewModel(
            container: container,
        )
        reopened.onAppear()
        await reopened.recentTypesReadTask?.value
        #expect(
            reopened.state is SelectUSExaminationTypeContentState,
        )
        let recent = try #require(
            reopened.sections.first {
                $0.id == "recent"
            },
        )
        #expect(
            recent.items.map(
                \.type.id,
            ) == [type.id],
        )
        reopened.onDisappear()
    }

    @Test
    func failedRecentReadKeepsCatalogAvailableAndReloadsOnReopening() async throws {
        let repository = StateReportRepository()
        repository.isRecentTypesReadFailed = true
        let type = USExaminationType(
            id: "bladder",
            title: "Bladder",
            contextualStrings: [],
        )
        try await repository.setRecentExaminationTypeIds(
            [type.id],
        )
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
            usExaminationTypesById: [type.id: type],
        )
        let messager = DMessager()
        var errorCount = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errorCount += 1
        }
        defer {
            observation.cancel()
        }
        let model = makeViewModel(
            container: container,
            messager: messager,
        )
        let configuredGroups = model.sections.map(
            \.id,
        )
        #expect(
            model.state is SelectUSExaminationTypeContentState,
        )
        model.onAppear()
        await model.recentTypesReadTask?.value
        #expect(
            model.state is SelectUSExaminationTypeContentState,
        )

        #expect(
            model.sections.map(
                \.id,
            ) == configuredGroups,
        )
        #expect(
            errorCount == 0,
        )

        repository.isRecentTypesReadFailed = false
        model.onDisappear()
        let reopened = makeViewModel(
            container: container,
        )
        reopened.onAppear()
        await reopened.recentTypesReadTask?.value
        #expect(
            reopened.state is SelectUSExaminationTypeContentState,
        )
        let recent = try #require(
            reopened.sections.first {
                $0.id == "recent"
            },
        )
        #expect(
            recent.items.map(
                \.type.id,
            ) == [type.id],
        )
        reopened.onDisappear()
    }

    @Test
    func requiredSelectionFailurePreservesValueAndReportsError() async throws {
        let repository = StateReportRepository()
        repository.isSelectionSaveFailed = true
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        let initial = ModulePreviewFactory.examinationType
        let other = USExaminationType(
            id: "bladder",
            title: "Bladder",
            contextualStrings: [],
        )
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
        }
        defer {
            observation.cancel()
        }
        let model = makeViewModel(
            container: container,
            messager: messager,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: initial,
                onSelected: { type in
                    try await repository.setSelectedExaminationTypeId(
                        id: type.id,
                    )
                },
            ),
        )
        model.onTypeTap(
            other,
        )
        model.onTypeTap(
            other,
        )
        await model.lastTask?.value
        #expect(
            model.currentValue == initial && model.state is SelectUSExaminationTypeContentState,
        )
        #expect(
            repository.selectionSaveCount == 1 && repository.recentExaminationTypeIds.isEmpty && errors == 1,
        )
        repository.isSelectionSaveFailed = false
        model.onTypeTap(
            other,
        )
        await model.lastTask?.value
        await model.recentTypeRecordTask?.value
        #expect(
            model.currentValue == other && repository.selectedExaminationTypeId == other.id,
        )
        #expect(
            repository.recentExaminationTypeIds == [other.id] && errors == 1,
        )
        model.onDisappear()
    }

    @Test
    func recentWriteFailureDoesNotFailTheRequiredSelection() async throws {
        let repository = StateReportRepository()
        repository.isRecentTypesWriteFailed = true
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        let type = ModulePreviewFactory.examinationType
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
        }
        defer {
            observation.cancel()
        }
        let model = makeViewModel(
            container: container,
            messager: messager,
            arguments: SelectUSExaminationTypeArguments(
                onSelected: { type in
                    try await repository.setSelectedExaminationTypeId(
                        id: type.id,
                    )
                },
            ),
        )
        model.onTypeTap(
            type,
        )
        await model.lastTask?.value
        await model.recentTypeRecordTask?.value
        #expect(
            model.currentValue == type && repository.selectedExaminationTypeId == type.id,
        )
        #expect(
            repository.recentExaminationTypeIds.isEmpty && errors == 0,
        )
        model.onDisappear()
    }

    @Test
    func optionalRecentWriteCompletesAfterTheSheetCloses() async throws {
        let repository = StateReportRepository()
        var response: CheckedContinuation<Void, Error>?
        repository.onRecentTypeRecord = {
            try await withCheckedThrowingContinuation {
                response = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        let model = makeViewModel(
            container: container,
        )
        let type = ModulePreviewFactory.examinationType
        model.onTypeTap(
            type,
        )
        await model.lastTask?.value
        while response == nil {
            await Task.yield()
        }
        model.onDisappear()
        #expect(
            model.currentValue == type,
        )
        response?.resume()
        await model.recentTypeRecordTask?.value
        #expect(
            repository.recentExaminationTypeIds == [type.id],
        )
    }

    @Test(
        arguments: [true, false],
    )
    func dismissedSelectionIgnoresLateResults(
        isFailure: Bool,
    ) async {
        let repository = StateReportRepository()
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
        )
        let initial = ModulePreviewFactory.examinationType
        let other = USExaminationType(
            id: "bladder",
            title: "Bladder",
            contextualStrings: [],
        )
        var response: CheckedContinuation<Void, Error>?
        let messager = DMessager()
        var messages = 0
        let observation = messager.$message.dropFirst().sink { _ in
            messages += 1
        }
        defer {
            observation.cancel()
        }
        let model = makeViewModel(
            container: container,
            messager: messager,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: initial,
                onSelected: { _ in
                    try await withCheckedThrowingContinuation {
                        response = $0
                    }
                },
            ),
        )
        model.onTypeTap(
            other,
        )
        let operation = model.lastTask
        while response == nil {
            await Task.yield()
        }
        model.onDisappear()
        if isFailure {
            response?.resume(
                throwing: CocoaError(
                    .fileWriteUnknown,
                ),
            )
        } else {
            response?.resume()
        }
        await operation?.value
        #expect(
            model.currentValue == initial && messages == 0,
        )
        #expect(
            repository.recentExaminationTypeIds.isEmpty,
        )
    }

    private func makeViewModel(
        container: DependencyContainer,
        messager: DMessager? = nil,
        arguments: SelectUSExaminationTypeArguments? = nil,
    ) -> SelectUSExaminationTypeViewModel {
        SelectUSExaminationTypeViewModel(
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
            arguments: arguments,
        )
    }
}
