#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "TemplateAddDefaultState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateAddFailedState",
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

    #Preview(
        "TemplateAddLoadingState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
