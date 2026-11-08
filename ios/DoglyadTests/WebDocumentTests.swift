#if DEBUG
    import Combine
    @testable import Doglyad
    import Foundation
    import Router
    import Testing

    @MainActor
    struct WebDocumentTests {
        @Test
        func retryIgnoresCallbacksFromThePreviousDocumentLoad() {
            let container = ModulePreviewFactory.makeContainer()
            let model = WebDocumentViewModel(
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
