#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 UserSettingsInitialState WorkPreferences",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 UserSettingsInitialState WorkPreferences ScrollEnd",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 UserSettingsErrorState PreferencesSaveFailed",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 UserSettingsErrorState PreferencesSaveFailed ScrollEnd",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsErrorState(
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
