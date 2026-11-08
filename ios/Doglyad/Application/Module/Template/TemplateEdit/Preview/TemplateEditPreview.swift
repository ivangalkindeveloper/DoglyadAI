#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateEditInitializationLoadingState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitializationLoadingState(),
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
        "03 TemplateEditInitialState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateEditSaveLoadingState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditSaveLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 TemplateEditDeleteLoadingState",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditDeleteLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 TemplateEditFailedState",
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
