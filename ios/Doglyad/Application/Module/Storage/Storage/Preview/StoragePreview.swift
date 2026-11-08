#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 StorageInitialState",
    ) {
        StoragePreviewView(
            state: StorageInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 StorageProtocolsClearLoadingState",
    ) {
        StoragePreviewView(
            state: StorageProtocolsClearLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 StorageSpeechModelDeleteLoadingState",
    ) {
        StoragePreviewView(
            state: StorageSpeechModelDeleteLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 StorageAllClearLoadingState",
    ) {
        StoragePreviewView(
            state: StorageAllClearLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 StorageFailedState",
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
#endif
