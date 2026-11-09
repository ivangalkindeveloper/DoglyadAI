import Combine
@testable import Doglyad
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct LocalFormOperationTests {
    @Test(
        arguments: [false, true],
    )
    func closingTemplateEditorRejectsLateReadResults(
        isFailure: Bool,
    ) async {
        let repository = DesignTemplateRepository(
            template: ModulePreviewFactory.template,
        )
        repository.isReadFailed = isFailure
        var resume: CheckedContinuation<Void, Never>?
        repository.onRead = {
            await withCheckedContinuation {
                resume = $0
            }
        }
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            templateRepository: repository,
        )
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
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
        let initial = model.state
        model.onAppear()
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.nameTextController.setText(
            "Entered while reading",
        )
        model.onDisappear()
        resume?.resume()
        await task?.value
        #expect(
            model.state === initial && errors == 0,
        )
        #expect(
            model.nameTextController.text == "Entered while reading" && model.templateTextController.text.isEmpty,
        )
    }

    @Test
    func settingsSaveRetainsEditsMadeDuringTheWrite() async {
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
        var resume: CheckedContinuation<Void, Never>?
        var writes: [Bool] = []
        let model = UserSettingsViewModel(
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
                "doctor@example.com"
            },
            getInitialIsRecommendationsIncluded: {
                true
            },
            getInitialIsPhotoRemarks: {
                false
            },
            getInitialIsDescriptionRemarks: {
                false
            },
            onSaved: { _, recommendations, _, _ in
                writes.append(
                    recommendations,
                )
                if writes.count == 1 {
                    await withCheckedContinuation {
                        resume = $0
                    }
                }
            },
        )
        let initial = model.state
        model.onTapSave()
        let first = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        #expect(
            model.state === initial,
        )
        model.toggleRecommendationsIncluded()
        resume?.resume()
        await first?.value
        #expect(
            writes == [true] && !model.isRecommendationsIncluded && router.path.count == 1,
        )
        model.onTapSave()
        await model.lastTask?.value
        #expect(
            writes == [true, false] && router.path.isEmpty,
        )
        model.onDisappear()
    }
}
