#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "LegalUpdateAwaitingAcceptanceState",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateAwaitingAcceptanceState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "LegalUpdateFailedState",
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

    #Preview(
        "LegalUpdateLoadingState",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
