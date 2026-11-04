#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "WebDocumentFailedState",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "WebDocumentLoadedState",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "WebDocumentLoadingState",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
