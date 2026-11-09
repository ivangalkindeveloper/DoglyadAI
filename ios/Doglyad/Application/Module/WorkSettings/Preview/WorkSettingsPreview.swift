#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 WorkSettingsInitialState WorkPreferences",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 WorkSettingsInitialState WorkPreferences ScrollEnd",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 WorkSettingsInitialState PatientConsentDisabled",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsInitialState(),
            isNeedPatientConsent: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 WorkSettingsInitialState PatientConsentDisabled ScrollEnd",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsInitialState(),
            isNeedPatientConsent: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 WorkSettingsErrorState PreferencesSaveFailed",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 WorkSettingsErrorState PreferencesSaveFailed ScrollEnd",
    ) {
        WorkSettingsPreviewView(
            state: WorkSettingsErrorState(
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
