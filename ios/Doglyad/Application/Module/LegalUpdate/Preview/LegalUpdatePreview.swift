#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 LegalUpdateAwaitingAcceptanceState ConsentNotSelected",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateAwaitingAcceptanceState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 LegalUpdateAwaitingAcceptanceState ConsentSelected",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateAwaitingAcceptanceState(),
            isLegalAccepted: true,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 LegalUpdateErrorState ConsentSaveFailed",
    ) {
        LegalUpdatePreviewView(
            state: LegalUpdateErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
            isLegalAccepted: true,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
