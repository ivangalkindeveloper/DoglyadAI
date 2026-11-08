#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateAddInitializationLoadingState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddInitializationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateAddInitialState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 TemplateAddSaveLoadingState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddSaveLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateAddFailedState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
