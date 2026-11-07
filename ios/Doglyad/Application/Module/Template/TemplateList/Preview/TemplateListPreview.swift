#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateListLoadingState",
    ) {
        TemplateListPreviewView(
            state: TemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateListFailedState",
    ) {
        TemplateListPreviewView(
            state: TemplateListFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 TemplateListEmptyState",
    ) {
        TemplateListPreviewView(
            state: TemplateListEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateListContentState",
    ) {
        TemplateListPreviewView(
            state: TemplateListContentState(
                templates: [ModulePreviewFactory.template],
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
