#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectTemplateContentState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectTemplateEmptyState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectTemplateFailedState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectTemplateLoadingState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
