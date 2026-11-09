#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 StorageInitialState StoredData",
    ) {
        StoragePreviewView(
            state: StorageInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 StorageInitialState StoredData ScrollEnd",
    ) {
        StoragePreviewView(
            state: StorageInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 StorageInitialState SpeechModelNotDownloaded",
    ) {
        StoragePreviewView(
            state: StorageInitialState(),
            isSpeechModelAvailable: false,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 StorageInitialState SpeechModelNotDownloaded ScrollEnd",
    ) {
        StoragePreviewView(
            state: StorageInitialState(),
            isSpeechModelAvailable: false,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 StorageErrorState ClearOperationFailed",
    ) {
        StoragePreviewView(
            state: StorageErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 StorageErrorState ClearOperationFailed ScrollEnd",
    ) {
        StoragePreviewView(
            state: StorageErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
