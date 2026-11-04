import Combine
@testable import Doglyad
import Router
import Testing

@MainActor
struct SelectUSExaminationTypeTests {
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
        await first.lastTask?.value
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
        #expect(
            repository.recentExaminationTypeIds == [type.id],
        )
        first.onDisappear()

        let reopened = makeViewModel(
            container: container,
        )
        reopened.onAppear()
        await reopened.lastTask?.value
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
    func failedInitialReadCanRetryAndDisplayRecentTypes() async throws {
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
        let model = makeViewModel(
            container: container,
        )
        model.onAppear()
        await model.lastTask?.value
        #expect(
            model.state is SelectUSExaminationTypeFailedState,
        )

        repository.isRecentTypesReadFailed = false
        model.onTapRetry()
        await model.lastTask?.value
        #expect(
            model.state is SelectUSExaminationTypeContentState,
        )
        let recent = try #require(
            model.sections.first {
                $0.id == "recent"
            },
        )
        #expect(
            recent.items.map(
                \.type.id,
            ) == [type.id],
        )
        model.onDisappear()
    }

    private func makeViewModel(
        container: DependencyContainer,
    ) -> SelectUSExaminationTypeViewModel {
        SelectUSExaminationTypeViewModel(
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
            arguments: nil,
        )
    }
}
