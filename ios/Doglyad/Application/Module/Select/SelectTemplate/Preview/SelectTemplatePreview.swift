#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTemplateContentState SavedTemplates",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateContentState(),
            templates: ModulePreviewFactory.templates,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectTemplateContentState SavedTemplates ScrollEnd",
    ) {
        SelectTemplatePreviewView(
            state: SelectTemplateContentState(),
            templates: ModulePreviewFactory.templates,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

#endif
