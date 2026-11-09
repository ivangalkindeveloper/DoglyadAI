#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SettingsAIInitialState CurrentPreferences",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SettingsAIInitialState CurrentPreferences ScrollEnd",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SettingsAIErrorState PreferencesSaveFailed",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SettingsAIErrorState PreferencesSaveFailed ScrollEnd",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIErrorState(
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
