#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "StorageFailedState",
    ) {
        StoragePreviewView(
            state: StorageFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "StorageLoadingState",
    ) {
        StoragePreviewView(
            state: StorageLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "StorageReadyState",
    ) {
        StoragePreviewView(
            state: StorageReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
