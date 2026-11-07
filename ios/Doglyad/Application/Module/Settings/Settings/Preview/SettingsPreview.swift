#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SettingsLoadingState",
    ) {
        SettingsPreviewView(
            state: SettingsLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SettingsFailedState",
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
        "03 SettingsContentState",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
