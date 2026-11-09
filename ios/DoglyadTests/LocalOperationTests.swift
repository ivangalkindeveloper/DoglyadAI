import Combine
@testable import Doglyad
import Foundation
import Router
import Testing

@MainActor
struct LocalOperationTests {
    @Test
    func localWriteKeepsPresentationAndRejectsDuplicateActions() async {
        let model = makeModel()
        let initial = model.state
        var resume: CheckedContinuation<Void, Never>?
        var calls = 0
        var successes = 0
        var failures = 0
        model.performLocalOperation {
            calls += 1
            await withCheckedContinuation {
                resume = $0
            }
        } onSuccess: { _ in
            successes += 1
        } onFailure: { _ in
            failures += 1
        }
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.performLocalOperation {
            calls += 1
        } onSuccess: { _ in
            successes += 1
        } onFailure: { _ in
            failures += 1
        }
        #expect(
            model.state === initial && calls == 1 && successes == 0,
        )
        resume?.resume()
        await task?.value
        #expect(
            model.state === initial && successes == 1 && failures == 0 && model.operationTask == nil,
        )
    }

    @Test(
        arguments: [false, true],
    )
    func cancelledLocalWriteIgnoresLateResultAndCannotReplaceNewOperation(
        isFailure: Bool,
    ) async {
        let model = makeModel()
        var resume: CheckedContinuation<Void, Never>?
        var callbacks = 0
        model.performLocalOperation {
            await withCheckedContinuation {
                resume = $0
            }
            if isFailure {
                throw CocoaError(
                    .fileWriteUnknown,
                )
            }
        } onSuccess: { _ in
            callbacks += 1
        } onFailure: { _ in
            callbacks += 1
        }
        let first = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.onDisappear()
        model.performLocalOperation {} onSuccess: { _ in
            callbacks += 10
        } onFailure: { _ in
            callbacks += 100
        }
        let second = model.lastTask
        resume?.resume()
        await first?.value
        await second?.value
        #expect(
            callbacks == 10 && model.operationTask == nil,
        )
    }

    @Test
    func failureIsReportedWithoutInventingALoadingPresentation() async {
        let model = makeModel()
        let initial = model.state
        var failures = 0
        model.performLocalOperation {
            throw CocoaError(
                .fileWriteUnknown,
            )
        } onSuccess: { _ in
            Issue.record(
                "A failed write cannot succeed",
            )
        } onFailure: { _ in
            failures += 1
        }
        await model.lastTask?.value
        #expect(
            failures == 1 && model.state === initial && model.operationTask == nil,
        )
    }

    @Test
    func leavingBeforeLocalWriteStartsDoesNotSendIt() async {
        let model = makeModel()
        var calls = 0
        var callbacks = 0
        model.performLocalOperation {
            calls += 1
        } onSuccess: { _ in
            callbacks += 1
        } onFailure: { _ in
            callbacks += 1
        }
        let task = model.lastTask
        model.onDisappear()
        await task?.value
        #expect(
            calls == 0 && callbacks == 0 && model.operationTask == nil,
        )
    }

    private func makeModel() -> DModuleViewModel<any StorageStateProtocol> {
        let container = DependencyContainer.previewable
        return DModuleViewModel(
            state: StorageInitialState(),
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .storage,
                ),
            ),
            getSubscriptionStatus: {
                nil
            },
            observeSubscriptionStatus: { _ in
                AnyCancellable {}
            },
            getSettingsAI: {
                container.initialSettingsAI
            },
            onRefreshSubscriptionStatus: {},
            onSubscriptionStatusUpdated: { _ in },
            analyticsDestination: .screen(
                .storage,
            ),
        )
    }
}
