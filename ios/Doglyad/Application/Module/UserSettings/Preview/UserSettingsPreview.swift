#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "UserSettingsDefaultState",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "UserSettingsFailedState",
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

    #Preview(
        "UserSettingsLoadingState",
    ) {
        UserSettingsPreviewView(
            state: UserSettingsLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
