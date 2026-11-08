#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SettingsAIInitialState",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SettingsAILoadingState",
    ) {
        SettingsAIPreviewView(
            state: SettingsAILoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 SettingsAIFailedState",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
