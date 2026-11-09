#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateEditInitializationErrorState TemplateReadFailed",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitializationErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateEditInitializationErrorState TemplateReadFailed ScrollEnd",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitializationErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 TemplateEditInitialState EditableTemplate",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateEditInitialState EditableTemplate ScrollEnd",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 TemplateEditErrorState TemplateOperationFailed",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 TemplateEditErrorState TemplateOperationFailed ScrollEnd",
    ) {
        TemplateEditPreviewView(
            state: TemplateEditErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
