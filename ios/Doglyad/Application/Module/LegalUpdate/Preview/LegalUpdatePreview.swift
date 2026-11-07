#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 LegalUpdateAwaitingAcceptanceState",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateAwaitingAcceptanceState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 LegalUpdateLoadingState",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 LegalUpdateFailedState",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
