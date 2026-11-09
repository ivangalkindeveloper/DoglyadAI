#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateListErrorState TemplatesReadFailed",
    ) {
        TemplateListPreviewView(
            state: TemplateListErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateListEmptyState NoSavedTemplates",
    ) {
        TemplateListPreviewView(
            state: TemplateListEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 TemplateListEmptyState NoSavedTemplates ScrollEnd",
    ) {
        TemplateListPreviewView(
            state: TemplateListEmptyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "04 TemplateListContentState SavedTemplates",
    ) {
        TemplateListPreviewView(
            state: TemplateListContentState(
                templates: ModulePreviewFactory.templates,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 TemplateListContentState SavedTemplates ScrollEnd",
    ) {
        TemplateListPreviewView(
            state: TemplateListContentState(
                templates: ModulePreviewFactory.templates,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
