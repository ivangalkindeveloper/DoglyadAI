#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SettingsContentState",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SettingsFailedState",
    ) {
        SettingsPreviewView(
            state: SettingsFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SettingsLoadingState",
    ) {
        SettingsPreviewView(
            state: SettingsLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
