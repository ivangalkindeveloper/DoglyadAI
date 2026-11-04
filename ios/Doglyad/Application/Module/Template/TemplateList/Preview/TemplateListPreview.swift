#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "TemplateListContentState",
    ) {
        TemplateListPreviewView(
            state: TemplateListContentState(
                templates: [ModulePreviewFactory.template],
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateListEmptyState",
    ) {
        TemplateListPreviewView(
            state: TemplateListEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "TemplateListFailedState",
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
        "TemplateListLoadingState",
    ) {
        TemplateListPreviewView(
            state: TemplateListLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
