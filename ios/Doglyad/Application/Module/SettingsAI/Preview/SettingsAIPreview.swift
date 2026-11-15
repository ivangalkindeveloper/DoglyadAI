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
        "03 SettingsAIInitialState TOneServerParsing",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIInitialState(),
            transcriberType: .tOne,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SettingsAIInitialState TOneServerParsing ScrollEnd",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIInitialState(),
            transcriberType: .tOne,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }

    #Preview(
        "05 SettingsAIErrorState PreferencesSaveFailed",
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
        "06 SettingsAIErrorState PreferencesSaveFailed ScrollEnd",
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
