#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 UserSettingsDefaultState",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 UserSettingsLoadingState",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 UserSettingsFailedState",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
