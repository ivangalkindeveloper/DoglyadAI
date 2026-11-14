#if DEBUG
    import Combine
    @testable import Doglyad
    @testable import DoglyadUI
    import Foundation
    import Router
    import Testing

    @MainActor
    struct WebDocumentTests {
        init() {}

        @Test
        func retryIgnoresCallbacksFromThePreviousDocumentLoad() {
            let container = ModulePreviewFactory.makeContainer()
            let messager = DMessager()
            var errorCount = 0
            let observation = messager.$message.dropFirst().sink { _ in
                errorCount += 1
            }
            defer {
                observation.cancel()
            }
            let model = WebDocumentViewModel(
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
                arguments: WebDocumentArguments(
                    url: URL(
                        string: "https://example.invalid/document",
                    )!,
                    title: "Document",
                ),
            )
            let initial = model.state
            let error = URLError(
                .notConnectedToInternet,
            )
            model.onDocumentFailed(
                error,
                from: initial,
            )
            #expect(
                model.documentStateIdentifier == "webDocument.failed",
            )

            model.onTapRetry()
            let retry = model.state
            #expect(
                model.documentStateIdentifier == "webDocument.loading",
            )
            #expect(
                retry !== initial,
            )

            model.onDocumentLoaded(
                from: initial,
            )
            model.onDocumentFailed(
                error,
                from: initial,
            )
            #expect(
                model.state === retry,
            )
            #expect(
                errorCount == 1,
            )

            model.onDocumentLoaded(
                from: retry,
            )
            let loaded = model.state
            #expect(
                model.documentStateIdentifier == "webDocument.loaded",
            )
            model.onDocumentFailed(
                error,
                from: retry,
            )
            model.onTapRetry()
            #expect(
                model.state === loaded,
            )
        }
    }
#endif
