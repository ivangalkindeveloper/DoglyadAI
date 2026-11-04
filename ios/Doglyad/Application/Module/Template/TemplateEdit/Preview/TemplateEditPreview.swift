#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "TemplateEditDefaultState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateEditFailedState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateEditInitializationFailedState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitializationFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateEditLoadingState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
