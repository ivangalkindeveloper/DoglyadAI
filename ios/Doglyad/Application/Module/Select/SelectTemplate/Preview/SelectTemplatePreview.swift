#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTemplateLoadingState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectTemplateFailedState",
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
        "03 SelectTemplateEmptyState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SelectTemplateContentState",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
