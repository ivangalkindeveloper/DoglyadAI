#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateAddLoadingState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateAddDefaultState",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 TemplateAddFailedState",
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
