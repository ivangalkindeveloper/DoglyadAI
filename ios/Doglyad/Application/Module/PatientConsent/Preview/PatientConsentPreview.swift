#if DEBUG
    import SwiftUI

    #Preview(
        "01 PatientConsentInitialState RequestConsent",
    ) {
        PatientConsentPreviewView(
            state: PatientConsentInitialState(),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PatientConsentInitialState DoNotAskAgainSelected",
    ) {
        PatientConsentPreviewView(
            state: PatientConsentInitialState(
                isDoNotAskAgain: true,
            ),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 PatientConsentInitialState PreferenceSaveFailed",
    ) {
        PatientConsentPreviewView(
            state: PatientConsentInitialState(
                isDoNotAskAgain: true,
            ),
            isErrorPresented: true,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
