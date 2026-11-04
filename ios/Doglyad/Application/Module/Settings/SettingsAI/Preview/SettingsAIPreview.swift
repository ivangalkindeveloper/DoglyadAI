#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SettingsAIDefaultState",
    ) {
        SettingsAIPreviewView(
            state: SettingsAIDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SettingsAIFailedState",
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

    #Preview(
        "SettingsAILoadingState",
    ) {
        SettingsAIPreviewView(
            state: SettingsAILoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
