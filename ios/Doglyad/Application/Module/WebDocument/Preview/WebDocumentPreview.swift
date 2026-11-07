#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 WebDocumentLoadingState",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 WebDocumentLoadedState",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 WebDocumentFailedState",
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
#endif
