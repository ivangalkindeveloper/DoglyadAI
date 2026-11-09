import Combine
@testable import Doglyad
import DoglyadUI
import Router
import Testing

@MainActor
struct StorageConfirmationTests {
    @Test
    func speechModelDeletionRequiresConfirmationAndCancellationKeepsTheModel() throws {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .storage,
            ),
        )
        let model = StorageViewModel(
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
        )
        model.configurePreviewSpeechModel(
            isAvailable: true,
        )
        model.onTapDeleteSpeechModel()
        #expect(
            router.sheet?.type == .storageClearSpeechModel,
        )
        _ = try #require(
            router.sheet?.arguments as? StorageClearSpeechModelArguments,
        )
        #expect(
            model.operationTask == nil && model.isSpeechModelAvailable,
        )
        router.dismissSheet()
        #expect(
            model.operationTask == nil && model.isSpeechModelAvailable,
        )
        model.configurePreviewSpeechModel(
            isAvailable: false,
        )
        model.onTapDeleteSpeechModel()
        #expect(
            router.sheet == nil,
        )
        model.onDisappear()
    }

    @Test
    func speechModelConfirmationDismissesAndCallsBackOnlyOnce() {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .storage,
            ),
        )
        var confirmations = 0
        let arguments = StorageClearSpeechModelArguments(
            onConfirm: {
                confirmations += 1
            },
        )
        router.push(
            route: RouteSheet(
                type: .storageClearSpeechModel,
                arguments: arguments,
            ),
        )
        let model = StorageClearSpeechModelViewModel(
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
            arguments: arguments,
        )
        model.onTapConfirm()
        model.onTapConfirm()
        #expect(
            confirmations == 1 && router.sheet == nil,
        )
        model.onDisappear()
        model.onTapConfirm()
        #expect(
            confirmations == 1,
        )
    }
}
