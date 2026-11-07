#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateEditLoadingState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateEditInitializationFailedState",
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
        "03 TemplateEditDefaultState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateEditFailedState",
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
#endif
