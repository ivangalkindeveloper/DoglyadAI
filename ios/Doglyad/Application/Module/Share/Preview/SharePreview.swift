#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ShareInitialState AvailableActions",
    ) {
        SharePreviewView(
            state: ShareInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ShareLoadingState PreparingDocument",
    ) {
        SharePreviewView(
            state: ShareLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ShareErrorState DocumentPreparationFailed",
    ) {
        SharePreviewView(
            state: ShareErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
